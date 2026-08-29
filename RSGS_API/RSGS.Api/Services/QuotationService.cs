using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Repositories.Interfaces;
using RSGS.Api.Utilities;
using RSGS.Api.Exceptions;
using System.Text;

namespace RSGS.Api.Services;

public class QuotationService : IQuotationService
{
    private readonly IQuotationRepository _repository;
    private readonly ICustomerRepository _customerRepository;
    private readonly IProjectRepository _projectRepository;
    private readonly IActivityLogService _activityLogService;
    private readonly ICurrentUserService _currentUser;
    private readonly IQuotationVersionService _versionService;
    private readonly IAuditService _auditService;
    private readonly AppDbContext _context;

    public QuotationService(
        IQuotationRepository repository,
        ICustomerRepository customerRepository,
        IProjectRepository projectRepository,
        IActivityLogService activityLogService,
        ICurrentUserService currentUser,
        AppDbContext context,
        IQuotationVersionService versionService,
        IAuditService auditService)
    {
        _repository = repository;
        _customerRepository = customerRepository;
        _projectRepository = projectRepository;
        _activityLogService = activityLogService;
        _currentUser = currentUser;
        _versionService = versionService;
        _context = context;
        _auditService = auditService;
    }

    public async Task<List<QuotationResponseDto>> GetAllAsync()
    {
        var engineerId = GetEngineerScope();

        var quotations = engineerId.HasValue
            ? await _repository.GetAllScopedAsync(engineerId.Value)
            : await _repository.GetAllAsync();

        return quotations
            .Select(MapToResponse)
            .ToList();
    }

    public async Task<QuotationResponseDto?> GetByIdAsync(int id)
    {
        var quotation =
            await _repository.GetDetailsAsync(id);

        if (quotation == null)
            return null;

        EnsureEngineerCanAccess(quotation);

        return MapToResponse(quotation);
    }

    public async Task<QuotationResponseDto> CreateAsync(CreateQuotationDto dto)
    {
        EnsureNotEngineerForManagement();

        ValidateQuotationType(dto);

        // =========================
        // Validate Customer
        // =========================

        var customer = await _customerRepository.GetByIdAsync(dto.CustomerId);

        if (customer == null)
            throw new BusinessException("Customer not found.");

        // =========================
        // Validate Project
        // =========================

        if (dto.ProjectId.HasValue)
        {
            var project =
                await _projectRepository.GetByIdAsync(dto.ProjectId.Value);

            if (project == null)
                throw new BusinessException("Project not found.");

            if (project.CustomerId != dto.CustomerId)
                throw new BusinessException(
                    "The selected project does not belong to the selected customer.");
        }

        // =========================
        // Generate Quotation Number
        // =========================
        // Quotation numbering uses a transaction-scoped PostgreSQL advisory lock
        // so concurrent creates cannot both observe the same MAX(number).
        await using var transaction = _context.Database.IsRelational()
            ? await _context.Database.BeginTransactionAsync()
            : null;

        await AcquireAdvisoryLockAsync(transaction, 10, DateTime.UtcNow.Year);

        var quotationNumber = await GenerateQuotationNumberAsync();

        // =========================
        // Build Items + Catalog Pricing
        // =========================

        var (items, catalogMaterialsCost) = await BuildItemsAsync(dto.Items);
        var materialsCost = dto.MaterialsCost + catalogMaterialsCost;

        var totalPrice = CalculateTotal(
            materialsCost,
            dto.TransportationCost,
            dto.InstallationCost,
            dto.OtherCost,
            dto.ProfitMargin,
            dto.Discount,
            dto.Tax);

        // =========================
        // Create Quotation
        // =========================

        var quotation = new Quotation
        {
            QuotationNumber = quotationNumber,

            Type = dto.Type,

            Status = QuotationStatus.Draft,

            CustomerId = dto.CustomerId,

            ProjectId = dto.ProjectId,

            QuotationDate = DateTimeUtility.ToUtc(dto.QuotationDate) ?? DateTime.UtcNow,

            ValidUntil = DateTimeUtility.ToUtc(dto.ValidUntil),

            SystemDescription = dto.SystemDescription,

            SystemCapacity = dto.SystemCapacity,

            CapacityUnit = dto.CapacityUnit,

            MaterialsCost = materialsCost,

            TransportationCost = dto.TransportationCost,

            InstallationCost = dto.InstallationCost,

            OtherCost = dto.OtherCost,

            ProfitMargin = dto.ProfitMargin,

            Discount = dto.Discount,

            Tax = dto.Tax,

            TotalPrice = totalPrice,

            Introduction = dto.Introduction,

            GeneralTerms = dto.GeneralTerms,

            PaymentTerms = dto.PaymentTerms,

            Notes = dto.Notes,

            CreatedAt = DateTime.UtcNow,

            UpdatedAt = DateTime.UtcNow
        };

        // =========================
        // Add Items
        // =========================

        foreach (var item in items)
        {
            quotation.Items.Add(item);
        }

        // =========================
        // Save
        // =========================

        await _repository.AddAsync(quotation);

        // =========================
        // Activity Log (detailed)
        // =========================

        await _auditService.CreateAsync(
            _currentUser.UserId,
            "Quotation",
            quotation.Id,
            null,
            new
            {
                quotation.QuotationNumber,
                quotation.Type,
                quotation.Status,
                quotation.CustomerId,
                quotation.ProjectId,
                QuotationDate = quotation.QuotationDate,
                quotation.ValidUntil,
                quotation.SystemDescription,
                quotation.SystemCapacity,
                quotation.CapacityUnit,
                quotation.MaterialsCost,
                quotation.TransportationCost,
                quotation.InstallationCost,
                quotation.OtherCost,
                quotation.ProfitMargin,
                quotation.Discount,
                quotation.Tax,
                quotation.TotalPrice,
                quotation.Introduction,
                quotation.GeneralTerms,
                quotation.PaymentTerms,
                quotation.Notes,
                ItemsSummary = string.Join("|", quotation.Items.Select(i => $"{i.ProductComponentId}:{i.Description}:{i.Quantity}:{i.UnitPrice}"))
            });

        if (transaction != null)
            await transaction.CommitAsync();

        return MapToResponse(quotation);
    }

    public async Task<QuotationResponseDto?> UpdateAsync(int id, UpdateQuotationDto dto)
    {
        EnsureNotEngineerForManagement();

        ValidateQuotationType(dto);

        await using var transaction = _context.Database.IsRelational()
            ? await _context.Database.BeginTransactionAsync()
            : null;

        // Serialize updates to the same quotation. This also makes version-number
        // generation safe when two users edit the same quotation concurrently.
        await AcquireAdvisoryLockAsync(transaction, 11, id);

        var quotation = await _repository.GetDetailsAsync(id);

        if (quotation == null)
        {
            if (transaction != null)
                await transaction.RollbackAsync();
            return null;
        }

        // =========================
        // Business Rule
        // =========================
        // Validate before creating a version snapshot. A rejected update must
        // leave absolutely no version/history side effects behind.
        if (quotation.Status == QuotationStatus.Approved)
        {
            throw new BusinessException(
                "Cannot update an approved quotation.");
        }

        // Preserve the exact pre-update state before replacing quotation items.
        // This is inside the same transaction/lock as the update.
        await _versionService.CreateSnapshotAsync(quotation, _currentUser.UserId, "Update");

        // =========================
        // Validate Customer
        // =========================

        var customer = await _customerRepository.GetByIdAsync(dto.CustomerId);

        if (customer == null)
            throw new BusinessException("Customer not found.");

        // =========================
        // Validate Project
        // =========================

        if (dto.ProjectId.HasValue)
        {
            var project =
                await _projectRepository.GetByIdAsync(dto.ProjectId.Value);

            if (project == null)
                throw new BusinessException("Project not found.");

            if (project.CustomerId != dto.CustomerId)
                throw new BusinessException(
                    "The selected project does not belong to the selected customer.");
        }

        // =========================
        // Rebuild Items + Catalog Pricing
        // =========================

        var (items, catalogMaterialsCost) = await BuildItemsAsync(dto.Items);
        var materialsCost = dto.MaterialsCost + catalogMaterialsCost;

        // Capture previous snapshot for audit
        var previousAudit = new
        {
            quotation.QuotationNumber,
            quotation.Type,
            quotation.Status,
            quotation.CustomerId,
            quotation.ProjectId,
            QuotationDate = quotation.QuotationDate,
            quotation.ValidUntil,
            quotation.SystemDescription,
            quotation.SystemCapacity,
            quotation.CapacityUnit,
            quotation.MaterialsCost,
            quotation.TransportationCost,
            quotation.InstallationCost,
            quotation.OtherCost,
            quotation.ProfitMargin,
            quotation.Discount,
            quotation.Tax,
            quotation.TotalPrice,
            quotation.Introduction,
            quotation.GeneralTerms,
            quotation.PaymentTerms,
            quotation.Notes,
            ItemsSummary = string.Join("|", quotation.Items.Select(i => $"{i.ProductComponentId}:{i.Description}:{i.Quantity}:{i.UnitPrice}"))
        };

        // =========================
        // Update Main Data
        // =========================

        quotation.Type = dto.Type;

        quotation.CustomerId = dto.CustomerId;

        quotation.ProjectId = dto.ProjectId;

        quotation.QuotationDate =
            DateTimeUtility.ToUtc(dto.QuotationDate)
            ?? quotation.QuotationDate;

        quotation.ValidUntil =
            DateTimeUtility.ToUtc(dto.ValidUntil);

        quotation.SystemDescription =
            dto.SystemDescription;

        quotation.SystemCapacity =
            dto.SystemCapacity;

        quotation.CapacityUnit =
            dto.CapacityUnit;

        quotation.MaterialsCost =
            materialsCost;

        quotation.TransportationCost =
            dto.TransportationCost;

        quotation.InstallationCost =
            dto.InstallationCost;

        quotation.OtherCost =
            dto.OtherCost;

        quotation.ProfitMargin =
            dto.ProfitMargin;

        quotation.Discount =
            dto.Discount;

        quotation.Tax =
            dto.Tax;

        quotation.TotalPrice = CalculateTotal(
            materialsCost,
            dto.TransportationCost,
            dto.InstallationCost,
            dto.OtherCost,
            dto.ProfitMargin,
            dto.Discount,
            dto.Tax);

        quotation.Introduction =
            dto.Introduction;

        quotation.GeneralTerms =
            dto.GeneralTerms;

        quotation.PaymentTerms =
            dto.PaymentTerms;

        quotation.Notes =
            dto.Notes;

        quotation.UpdatedAt =
            DateTime.UtcNow;

        // =========================
        // Update Items
        // =========================

        quotation.Items = items;

        await _repository.UpdateWithItemsAsync(quotation);

        var currentAudit = new
        {
            quotation.QuotationNumber,
            quotation.Type,
            quotation.Status,
            quotation.CustomerId,
            quotation.ProjectId,
            QuotationDate = quotation.QuotationDate,
            quotation.ValidUntil,
            quotation.SystemDescription,
            quotation.SystemCapacity,
            quotation.CapacityUnit,
            quotation.MaterialsCost,
            quotation.TransportationCost,
            quotation.InstallationCost,
            quotation.OtherCost,
            quotation.ProfitMargin,
            quotation.Discount,
            quotation.Tax,
            quotation.TotalPrice,
            quotation.Introduction,
            quotation.GeneralTerms,
            quotation.PaymentTerms,
            quotation.Notes,
            ItemsSummary = string.Join("|", quotation.Items.Select(i => $"{i.ProductComponentId}:{i.Description}:{i.Quantity}:{i.UnitPrice}"))
        };

        await _auditService.UpdateAsync(
            _currentUser.UserId,
            "Quotation",
            quotation.Id,
            previousAudit,
            currentAudit,
            new[] { "QuotationNumber", "Type", "Status", "CustomerId", "ProjectId", "QuotationDate", "ValidUntil", "SystemDescription", "SystemCapacity", "CapacityUnit", "MaterialsCost", "TransportationCost", "InstallationCost", "OtherCost", "ProfitMargin", "Discount", "Tax", "TotalPrice", "Introduction", "GeneralTerms", "PaymentTerms", "Notes", "ItemsSummary" });

        if (transaction != null)
            await transaction.CommitAsync();

        return MapToResponse(quotation);
    }

    public async Task<bool> DeleteAsync(int id)
    {
        EnsureNotEngineerForManagement();

        var quotation = await _repository.GetByIdAsync(id);

        if (quotation == null)
            return false;

        // =========================
        // Business Rules
        // =========================

        if (quotation.Status == QuotationStatus.Approved)
        {
            throw new BusinessException(
                "Cannot delete an approved quotation.");
        }

        if (quotation.Status == QuotationStatus.Sent)
        {
            throw new BusinessException(
                "Cannot delete a quotation that has been sent.");
        }

        var ownsTransaction = _context.Database.CurrentTransaction == null && _context.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _context.Database.BeginTransactionAsync()
            : null;

        if (_context.Database.IsRelational())
        {
            await _context.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock(42, {quotation.Id});");
        }

        quotation = await _repository.GetDetailsAsync(id) ?? quotation;

        if (quotation.Status is QuotationStatus.Approved or QuotationStatus.Sent)
            throw new BusinessException("Cannot delete an approved or sent quotation.");

        await _repository.DeleteAsync(quotation);

        await _auditService.DeleteAsync(
            _currentUser.UserId,
            "Quotation",
            quotation.Id,
            new
            {
                quotation.QuotationNumber,
                quotation.Type,
                quotation.Status,
                quotation.CustomerId,
                quotation.ProjectId,
                QuotationDate = quotation.QuotationDate,
                quotation.ValidUntil,
                quotation.SystemDescription,
                quotation.SystemCapacity,
                quotation.CapacityUnit,
                quotation.MaterialsCost,
                quotation.TransportationCost,
                quotation.InstallationCost,
                quotation.OtherCost,
                quotation.ProfitMargin,
                quotation.Discount,
                quotation.Tax,
                quotation.TotalPrice,
                quotation.Introduction,
                quotation.GeneralTerms,
                quotation.PaymentTerms,
                quotation.Notes,
                ItemsSummary = string.Join("|", quotation.Items.Select(i => $"{i.ProductComponentId}:{i.Description}:{i.Quantity}:{i.UnitPrice}"))
            },
            null,
            new[] { "QuotationNumber", "Type", "Status", "CustomerId", "ProjectId", "QuotationDate", "ValidUntil", "SystemDescription", "SystemCapacity", "CapacityUnit", "MaterialsCost", "TransportationCost", "InstallationCost", "OtherCost", "ProfitMargin", "Discount", "Tax", "TotalPrice", "Introduction", "GeneralTerms", "PaymentTerms", "Notes", "ItemsSummary" });

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return true;
    }

    private async Task<(List<QuotationItem> Items, decimal CatalogMaterialsCost)> BuildItemsAsync(
        List<QuotationItemDto> itemDtos)
    {
        var productIds = itemDtos
            .Where(x => x.ProductComponentId.HasValue)
            .Select(x => x.ProductComponentId!.Value)
            .Distinct()
            .ToList();

        var products = productIds.Count == 0
            ? new List<ProductComponent>()
            : await _context.ProductComponents
                .Where(x => productIds.Contains(x.Id))
                .ToListAsync();

        var productMap = products.ToDictionary(x => x.Id);
        var now = DateTime.UtcNow;
        decimal catalogMaterialsCost = 0;
        var result = new List<QuotationItem>(itemDtos.Count);

        foreach (var dto in itemDtos.OrderBy(x => x.SortOrder))
        {
            ProductComponent? product = null;

            if (dto.ProductComponentId.HasValue)
            {
                if (!productMap.TryGetValue(dto.ProductComponentId.Value, out product))
                    throw new BusinessException($"Product {dto.ProductComponentId.Value} was not found.");

                if (!dto.Quantity.HasValue || dto.Quantity.Value <= 0)
                    throw new BusinessException($"Quantity is required for product '{product.Code}'.");
            }

            var quantity = dto.Quantity;
            var unitCost = product?.CostPrice ?? dto.UnitCost;
            var unitPrice = product?.SellingPrice ?? dto.UnitPrice;
            var totalCost = unitCost.HasValue && quantity.HasValue
                ? decimal.Round(unitCost.Value * quantity.Value, 2)
                : 0m;
            var totalPrice = unitPrice.HasValue && quantity.HasValue
                ? decimal.Round(unitPrice.Value * quantity.Value, 2)
                : 0m;

            if (product != null)
                catalogMaterialsCost += totalCost;

            result.Add(new QuotationItem
            {
                ProductComponentId = product?.Id,
                ProductComponent = product,
                Description = product?.Specification ?? dto.Description.Trim(),
                Item = product == null
                    ? dto.Item.Trim()
                    : string.Join(" ", new[] { product.Name, product.Brand, product.Model }
                        .Where(x => !string.IsNullOrWhiteSpace(x))),
                Category = product?.Category ?? dto.Category,
                Quantity = quantity,
                Unit = product?.Unit ?? dto.Unit?.Trim(),
                CountryOfOrigin = product?.CountryOfOrigin ?? dto.CountryOfOrigin?.Trim(),
                UnitCost = unitCost,
                UnitPrice = unitPrice,
                TotalCost = totalCost,
                TotalPrice = totalPrice,
                SortOrder = dto.SortOrder,
                InternalNotes = string.IsNullOrWhiteSpace(dto.InternalNotes) ? null : dto.InternalNotes.Trim(),
                CreatedAt = now,
                UpdatedAt = now
            });
        }

        return (result, decimal.Round(catalogMaterialsCost, 2));
    }

    // =========================
    // Pricing Calculation
    // =========================

    private static decimal CalculateTotal(
        decimal materialsCost,
        decimal transportationCost,
        decimal installationCost,
        decimal otherCost,
        decimal profitMargin,
        decimal discount,
        decimal tax)
    {
        // ProfitMargin and Tax are percentages (0-100), as defined by the DTOs.
        var baseCost =
            materialsCost
            + transportationCost
            + installationCost
            + otherCost;

        var profitAmount = baseCost * (profitMargin / 100m);

        var subtotal = baseCost
            + profitAmount
            - discount;

        if (subtotal < 0)
            subtotal = 0;

        var taxAmount = subtotal * (tax / 100m);

        var total = subtotal + taxAmount;

        return Math.Max(0, decimal.Round(total, 2));
    }

    // =========================
    // Quotation Number
    // =========================

    private async Task AcquireAdvisoryLockAsync(
        Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction? transaction,
        int resourceType,
        int resourceId)
    {
        if (transaction == null)
            return;

        // PostgreSQL transaction-scoped advisory locks are released automatically
        // when the surrounding transaction commits or rolls back. The two-int
        // namespace keeps quotation locks separate from other domain locks.
        await _context.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT pg_advisory_xact_lock({resourceType}, {resourceId});");
    }

    private async Task<string> GenerateQuotationNumberAsync()
    {
        var year = DateTime.UtcNow.Year;

        var quotations = await _repository.GetAllAsync();

        var prefix = $"QT-{year}-";

        var maxNumber = quotations
            .Where(x =>
                !string.IsNullOrWhiteSpace(x.QuotationNumber) &&
                x.QuotationNumber.StartsWith(prefix))
            .Select(x =>
            {
                var numberPart = x.QuotationNumber[prefix.Length..];

                return int.TryParse(numberPart, out var number)
                    ? number
                    : 0;
            })
            .DefaultIfEmpty(0)
            .Max();

        return $"{prefix}{(maxNumber + 1):D4}";
    }

    public async Task<QuotationResponseDto?> ChangeStatusAsync(
    int id,
    QuotationStatus status,
    QuotationSendTrackingDto? tracking = null)
    {
        if (!Enum.IsDefined(status))
            throw new BusinessException("Invalid quotation status.");

        var quotation = await _repository.GetByIdAsync(id);

        if (quotation == null)
            return null;

        await using var transaction = _context.Database.IsRelational()
            ? await _context.Database.BeginTransactionAsync()
            : null;

        if (_context.Database.IsRelational())
        {
            await _context.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock(42, {id});");
        }

        // Re-read after the lock so the transition is validated against the
        // latest committed status rather than a stale concurrent read.
        quotation = await _repository.GetByIdAsync(id);
        if (quotation == null)
            return null;

        var currentStatus = quotation.Status;

        // =========================
        // Validate Status Transition
        // =========================

        if (currentStatus == QuotationStatus.Approved)
        {
            throw new BusinessException(
                "Cannot change the status of an approved quotation.");
        }

        if (currentStatus == QuotationStatus.Rejected)
        {
            throw new BusinessException(
                "Cannot change the status of a rejected quotation.");
        }

        if (currentStatus == QuotationStatus.Expired)
        {
            throw new BusinessException(
                "Cannot change the status of an expired quotation.");
        }

        // =========================
        // Allowed Transitions
        // =========================

        if (currentStatus == QuotationStatus.Draft)
        {
            if (status != QuotationStatus.Sent)
            {
                throw new BusinessException(
                    "A draft quotation can only be sent.");
            }
        }

        if (currentStatus == QuotationStatus.Sent)
        {
            if (status != QuotationStatus.Approved &&
                status != QuotationStatus.Rejected &&
                status != QuotationStatus.Expired)
            {
                throw new BusinessException(
                    "A sent quotation can only be approved, rejected, or expired.");
            }
        }

        // =========================
        // Update
        // =========================

        quotation.Status = status;
        quotation.UpdatedAt = DateTime.UtcNow;

        if (status == QuotationStatus.Sent)
        {
            quotation.SentAt = DateTime.UtcNow;
            quotation.SentByUserId = _currentUser.UserId;
            quotation.SentMethod = string.IsNullOrWhiteSpace(tracking?.Method) ? "Manual" : tracking!.Method.Trim();
            quotation.SentRecipient = tracking?.Recipient?.Trim();
        }

        await _repository.UpdateAsync(quotation);

        // =========================
        // Activity Log
        // =========================

        await _activityLogService.CreateAsync(
            _currentUser.UserId,
            "StatusChange",
            "Quotation",
            quotation.Id,
            $"Quotation '{quotation.QuotationNumber}' status changed from '{currentStatus}' to '{status}'.");

        if (transaction != null)
            await transaction.CommitAsync();

        return MapToResponse(quotation);
    }

    private int? GetEngineerScope()
    {
        return _currentUser.Role == UserRole.Engineer.ToString()
            ? _currentUser.UserId
            : null;
    }

    private void EnsureEngineerCanAccess(Quotation quotation)
    {
        if (!GetEngineerScope().HasValue)
            return;

        var engineerId = _currentUser.UserId;

        var hasAccess =
            (quotation.ProjectId.HasValue &&
             quotation.Project?.EngineerId == engineerId)
            ||
            (quotation.Customer?.AssignedUserId == engineerId);

        if (!hasAccess)
        {
            throw new BusinessException(
                "You can only access quotations assigned to you.");
        }
    }

    private void EnsureNotEngineerForManagement()
    {
        if (GetEngineerScope().HasValue)
        {
            throw new BusinessException(
                "Engineers do not have permission to manage quotations.");
        }
    }

    private static QuotationResponseDto MapToResponse(
        Quotation quotation)
    {
        return new QuotationResponseDto
        {
            Id = quotation.Id,

            QuotationNumber = quotation.QuotationNumber,

            Type = quotation.Type,

            Status = quotation.Status,

            CustomerId = quotation.CustomerId,

            ProjectId = quotation.ProjectId,

            QuotationDate = quotation.QuotationDate,

            ValidUntil = quotation.ValidUntil,

            SystemDescription = quotation.SystemDescription,

            SystemCapacity = quotation.SystemCapacity,

            CapacityUnit = quotation.CapacityUnit,

            TotalPrice = quotation.TotalPrice,

            MaterialsCost = quotation.MaterialsCost,
            TransportationCost = quotation.TransportationCost,
            InstallationCost = quotation.InstallationCost,
            OtherCost = quotation.OtherCost,
            ProfitMargin = quotation.ProfitMargin,
            Discount = quotation.Discount,
            Tax = quotation.Tax,

            Introduction = quotation.Introduction,

            GeneralTerms = quotation.GeneralTerms,

            PaymentTerms = quotation.PaymentTerms,

            Notes = quotation.Notes,

            SentAt = quotation.SentAt,
            SentByUserId = quotation.SentByUserId,
            SentMethod = quotation.SentMethod,
            SentRecipient = quotation.SentRecipient,

            Items = quotation.Items
                .OrderBy(x => x.SortOrder)
                .Select(x => new QuotationItemResponseDto
                {
                    Id = x.Id,
                    ProductComponentId = x.ProductComponentId,
                    ProductCode = x.ProductComponent?.Code,
                    ProductName = x.ProductComponent?.Name,

                    Description = x.Description,

                    Item = x.Item,

                    Category = x.Category,

                    Quantity = x.Quantity,

                    Unit = x.Unit,

                    CountryOfOrigin = x.CountryOfOrigin,
                    UnitCost = x.UnitCost,
                    UnitPrice = x.UnitPrice,
                    TotalCost = x.TotalCost,
                    TotalPrice = x.TotalPrice,

                    SortOrder = x.SortOrder,

                    InternalNotes = x.InternalNotes
                })
                .ToList()
        };
    }

    private static void ValidateQuotationType(
        CreateQuotationDto dto)
    {
        if (dto.Items == null || dto.Items.Count == 0)
        {
            throw new BusinessException(
                "Quotation must contain at least one item.");
        }

        var categories = dto.Items
            .Select(x => x.Category)
            .ToHashSet();

        switch (dto.Type)
        {
            case QuotationType.OnGrid:

                if (!dto.SystemCapacity.HasValue ||
                    dto.SystemCapacity <= 0)
                {
                    throw new BusinessException(
                        "On-Grid quotation must have a valid system capacity.");
                }

                ValidateOnGridItems(categories);

                break;


            case QuotationType.OffGrid:

                if (!dto.SystemCapacity.HasValue ||
                    dto.SystemCapacity <= 0)
                {
                    throw new BusinessException(
                        "Off-Grid quotation must have a valid system capacity.");
                }

                ValidateOnGridItems(categories);

                if (!categories.Contains(
                        QuotationItemCategory.Batteries))
                {
                    throw new BusinessException(
                        "Off-Grid quotation must contain batteries.");
                }

                var batteryItems = dto.Items
                    .Where(x =>
                        x.Category == QuotationItemCategory.Batteries)
                    .ToList();

                if (batteryItems.Any(x =>
                        !x.Quantity.HasValue ||
                        x.Quantity <= 0))
                {
                    throw new BusinessException(
                        "Off-Grid batteries must have a valid quantity.");
                }

                break;


            case QuotationType.SolarPump:

                if (!dto.SystemCapacity.HasValue ||
                    dto.SystemCapacity <= 0)
                {
                    throw new BusinessException(
                        "Solar Pump quotation must have a valid system capacity.");
                }

                ValidateSolarPumpItems(categories);

                break;


            default:

                throw new BusinessException(
                    "Invalid quotation type.");
        }
    }

    private static void ValidateOnGridItems(
    HashSet<QuotationItemCategory> categories)
    {
        var requiredCategories = new[]
        {
        QuotationItemCategory.SolarPanels,
        QuotationItemCategory.Structure,
        QuotationItemCategory.Inverter,
        QuotationItemCategory.DCCables,
        QuotationItemCategory.DCCombiner,
        QuotationItemCategory.CableTray,
        QuotationItemCategory.Grounding,
        QuotationItemCategory.MC4,
        QuotationItemCategory.Transportation,
        QuotationItemCategory.Installation,
        QuotationItemCategory.Maintenance
    };

        var missingCategories = requiredCategories
            .Where(category => !categories.Contains(category))
            .ToList();

        if (missingCategories.Count > 0)
        {
            var missing = string.Join(
                ", ",
                missingCategories);

            throw new BusinessException(
                $"On-Grid quotation is missing required items: {missing}");
        }
    }

    private static void ValidateSolarPumpItems(
        HashSet<QuotationItemCategory> categories)
    {
        var requiredCategories = new[]
        {
        QuotationItemCategory.SolarPanels,
        QuotationItemCategory.Structure,
        QuotationItemCategory.Inverter,
        QuotationItemCategory.DCCables,
        QuotationItemCategory.InverterPanel,
        QuotationItemCategory.DCCombiner,
        QuotationItemCategory.CablePipes,
        QuotationItemCategory.Grounding,
        QuotationItemCategory.MC4,
        QuotationItemCategory.Transportation,
        QuotationItemCategory.Installation,
        QuotationItemCategory.Maintenance
    };

        var missingCategories = requiredCategories
            .Where(category => !categories.Contains(category))
            .ToList();

        if (missingCategories.Count > 0)
        {
            var missing = string.Join(
                ", ",
                missingCategories);

            throw new BusinessException(
                $"Solar Pump quotation is missing required items: {missing}");
        }
    }

    private static void ValidateQuotationType(
        UpdateQuotationDto dto)
    {
        if (dto.Items == null || dto.Items.Count == 0)
        {
            throw new BusinessException(
                "Quotation must contain at least one item.");
        }

        var categories = dto.Items
            .Select(x => x.Category)
            .ToHashSet();

        switch (dto.Type)
        {
            case QuotationType.OnGrid:

                if (!dto.SystemCapacity.HasValue ||
                    dto.SystemCapacity <= 0)
                {
                    throw new BusinessException(
                        "On-Grid quotation must have a valid system capacity.");
                }

                ValidateOnGridItems(categories);

                break;


            case QuotationType.OffGrid:

                if (!dto.SystemCapacity.HasValue ||
                    dto.SystemCapacity <= 0)
                {
                    throw new BusinessException(
                        "Off-Grid quotation must have a valid system capacity.");
                }

                // Off-Grid must contain all On-Grid requirements
                ValidateOnGridItems(categories);

                // Batteries are mandatory
                if (!categories.Contains(
                        QuotationItemCategory.Batteries))
                {
                    throw new BusinessException(
                        "Off-Grid quotation must contain batteries.");
                }

                // Battery quantity must be valid
                var batteryItems = dto.Items
                    .Where(x =>
                        x.Category == QuotationItemCategory.Batteries)
                    .ToList();

                if (batteryItems.Any(x =>
                        !x.Quantity.HasValue ||
                        x.Quantity <= 0))
                {
                    throw new BusinessException(
                        "Off-Grid batteries must have a valid quantity.");
                }

                break;


            case QuotationType.SolarPump:

                if (!dto.SystemCapacity.HasValue ||
                    dto.SystemCapacity <= 0)
                {
                    throw new BusinessException(
                        "Solar Pump quotation must have a valid system capacity.");
                }

                ValidateSolarPumpItems(categories);

                break;


            default:

                throw new BusinessException(
                    "Invalid quotation type.");
        }
    }

}