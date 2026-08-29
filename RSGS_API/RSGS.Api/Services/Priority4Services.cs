using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Exceptions;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Utilities;

namespace RSGS.Api.Services;

public class SupplierService : ISupplierService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUserService _currentUser;
    private readonly IActivityLogService _activity;

    public SupplierService(AppDbContext db, ICurrentUserService currentUser, IActivityLogService activity)
    {
        _db = db; _currentUser = currentUser; _activity = activity;
    }

    public async Task<List<SupplierResponseDto>> GetAllAsync(bool activeOnly = false)
    {
        var query = _db.Suppliers.AsNoTracking();
        if (activeOnly) query = query.Where(x => x.IsActive);
        return await query.OrderBy(x => x.Name).Select(Map()).ToListAsync();
    }

    public async Task<SupplierResponseDto?> GetByIdAsync(int id) =>
        await _db.Suppliers.AsNoTracking().Where(x => x.Id == id).Select(Map()).SingleOrDefaultAsync();

    public async Task<SupplierResponseDto> CreateAsync(SupplierDto dto)
    {
        var code = dto.Code.Trim();
        await using var transaction = _db.Database.IsRelational()
            ? await _db.Database.BeginTransactionAsync()
            : null;

        // The existence check alone is racy. Serialize supplier-code creation so
        // two concurrent requests cannot both pass the check.
        if (transaction != null)
        {
            await _db.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock(51, hashtext({code}));");
        }

        if (await _db.Suppliers.AnyAsync(x => x.Code == code))
            throw new BusinessException("Supplier code already exists.");

        var now = DateTime.UtcNow;
        var entity = new Supplier
        {
            Code = code, Name = dto.Name.Trim(), ContactPerson = Clean(dto.ContactPerson), Phone = Clean(dto.Phone),
            Email = Clean(dto.Email), Address = Clean(dto.Address), TaxNumber = Clean(dto.TaxNumber), Notes = Clean(dto.Notes),
            IsActive = dto.IsActive, CreatedAt = now, UpdatedAt = now
        };
        _db.Suppliers.Add(entity);
        await _db.SaveChangesAsync();

        await _activity.CreateAsync(_currentUser.UserId, "Create", "Supplier", entity.Id, $"Supplier {entity.Name} created.");

        if (transaction != null)
            await transaction.CommitAsync();

        return (await GetByIdAsync(entity.Id))!;
    }

    public async Task<SupplierResponseDto?> UpdateAsync(int id, SupplierDto dto)
    {
        var entity = await _db.Suppliers.FirstOrDefaultAsync(x => x.Id == id);
        if (entity == null) return null;
        var code = dto.Code.Trim();
        var codeChanged = !string.Equals(entity.Code, code, StringComparison.Ordinal);

        await using var transaction = _db.Database.IsRelational()
            ? await _db.Database.BeginTransactionAsync()
            : null;

        if (transaction != null)
        {
            await _db.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock(51, hashtext({code}));");
        }

        if (codeChanged && await _db.Suppliers.AnyAsync(x => x.Id != id && x.Code == code))
            throw new BusinessException("Supplier code already exists.");

        entity.Code = code; entity.Name = dto.Name.Trim(); entity.ContactPerson = Clean(dto.ContactPerson);
        entity.Phone = Clean(dto.Phone); entity.Email = Clean(dto.Email); entity.Address = Clean(dto.Address);
        entity.TaxNumber = Clean(dto.TaxNumber); entity.Notes = Clean(dto.Notes); entity.IsActive = dto.IsActive;
        entity.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        await _activity.CreateAsync(_currentUser.UserId, "Update", "Supplier", id, $"Supplier {entity.Name} updated.");

        if (transaction != null)
            await transaction.CommitAsync();

        return await GetByIdAsync(id);
    }

    public async Task<bool> SetActiveAsync(int id, bool active)
    {
        var entity = await _db.Suppliers.FirstOrDefaultAsync(x => x.Id == id);
        if (entity == null) return false;
        entity.IsActive = active; entity.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        await _activity.CreateAsync(_currentUser.UserId, active ? "Enable" : "Disable", "Supplier", id, $"Supplier {entity.Name} {(active ? "enabled" : "disabled")}.");
        return true;
    }

    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static Expression<Func<Supplier, SupplierResponseDto>> Map() => x => new SupplierResponseDto
    {
        Id = x.Id, Code = x.Code, Name = x.Name, ContactPerson = x.ContactPerson, Phone = x.Phone,
        Email = x.Email, Address = x.Address, TaxNumber = x.TaxNumber, Notes = x.Notes, IsActive = x.IsActive,
        CreatedAt = x.CreatedAt, UpdatedAt = x.UpdatedAt
    };
}

public class InvoiceService : IInvoiceService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUserService _currentUser;
    private readonly IActivityLogService _activity;

    public InvoiceService(AppDbContext db, ICurrentUserService currentUser, IActivityLogService activity)
    {
        _db = db; _currentUser = currentUser; _activity = activity;
    }

    public async Task<List<InvoiceResponseDto>> GetAllAsync()
    {
        var rows = await _db.Invoices.AsNoTracking().Include(x => x.Customer).Include(x => x.Items).Include(x => x.Installments)
            .OrderByDescending(x => x.IssueDate).ThenByDescending(x => x.Id).ToListAsync();
        return rows.Select(Map).ToList();
    }

    public async Task<InvoiceResponseDto?> GetByIdAsync(int id)
    {
        var row = await _db.Invoices.AsNoTracking().Include(x => x.Customer).Include(x => x.Items).Include(x => x.Installments)
            .SingleOrDefaultAsync(x => x.Id == id);
        return row == null ? null : Map(row);
    }

    public async Task<InvoiceResponseDto> CreateAsync(CreateInvoiceDto dto)
    {
        if (dto.Status is not (InvoiceStatus.Draft or InvoiceStatus.Issued))
            throw new BusinessException("A new invoice can only be created as Draft or Issued.");

        var issueDate = DateTimeUtility.ToUtc(dto.IssueDate ?? DateTime.UtcNow);
        var dueDate = DateTimeUtility.ToUtc(dto.DueDate);
        if (dueDate.HasValue && dueDate.Value < issueDate)
            throw new BusinessException("Invoice due date cannot be earlier than the issue date.");

        var customer = await _db.Customers.FirstOrDefaultAsync(x => x.Id == dto.CustomerId) ?? throw new BusinessException("Customer not found.");
        if (dto.ProjectId.HasValue)
        {
            var project = await _db.Projects.FirstOrDefaultAsync(x => x.Id == dto.ProjectId.Value) ?? throw new BusinessException("Project not found.");
            if (project.CustomerId != dto.CustomerId) throw new BusinessException("Project does not belong to the selected customer.");
        }
        if (dto.QuotationId.HasValue)
        {
            var quotation = await _db.Quotations.FirstOrDefaultAsync(x => x.Id == dto.QuotationId.Value) ?? throw new BusinessException("Quotation not found.");
            if (quotation.CustomerId != dto.CustomerId) throw new BusinessException("Quotation does not belong to the selected customer.");
        }
        var entity = new Invoice
        {
            InvoiceNumber = GenerateNumber("INV"), CustomerId = dto.CustomerId, ProjectId = dto.ProjectId, QuotationId = dto.QuotationId,
            IssueDate = issueDate,
            DueDate = dueDate,
            Status = dto.Status, Tax = dto.Tax, Notes = Clean(dto.Notes), CreatedByUserId = _currentUser.UserId,
            CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow
        };
        foreach (var item in dto.Items)
        {
            if (item.ProductComponentId.HasValue && !await _db.ProductComponents.AnyAsync(x => x.Id == item.ProductComponentId.Value && x.IsActive))
                throw new BusinessException("One of the selected products is not active or does not exist.");
            entity.Items.Add(new InvoiceItem
            {
                ProductComponentId = item.ProductComponentId, Description = item.Description.Trim(), Quantity = item.Quantity,
                Unit = string.IsNullOrWhiteSpace(item.Unit) ? "pcs" : item.Unit.Trim(), UnitPrice = item.UnitPrice,
                Total = Math.Round(item.Quantity * item.UnitPrice, 2), SortOrder = item.SortOrder
            });
        }
        entity.Subtotal = entity.Items.Sum(x => x.Total);
        entity.Total = entity.Subtotal + entity.Tax;
        _db.Invoices.Add(entity);
        await _db.SaveChangesAsync();
        await _activity.CreateAsync(_currentUser.UserId, "Create", "Invoice", entity.Id, $"Invoice {entity.InvoiceNumber} created for {customer.Name}.");
        return (await GetByIdAsync(entity.Id))!;
    }

    public async Task<InvoiceResponseDto> CreateFromQuotationAsync(int quotationId)
    {
        var quotation = await _db.Quotations.FirstOrDefaultAsync(x => x.Id == quotationId)
            ?? throw new BusinessException("Quotation not found.");
        if (quotation.Status != QuotationStatus.Approved)
            throw new BusinessException("Only approved quotations can be invoiced.");

        var dto = new CreateInvoiceDto
        {
            CustomerId = quotation.CustomerId,
            ProjectId = quotation.ProjectId,
            QuotationId = quotation.Id,
            IssueDate = DateTime.UtcNow,
            Status = InvoiceStatus.Issued,
            Tax = 0,
            Notes = $"Created from quotation {quotation.QuotationNumber}",
            Items = new List<InvoiceItemDto>
            {
                new()
                {
                    Description = $"Solar project - {quotation.QuotationNumber}",
                    Quantity = 1,
                    Unit = "project",
                    UnitPrice = quotation.TotalPrice,
                    SortOrder = 0
                }
            }
        };

        return await CreateAsync(dto);
    }

    public async Task<PaymentResponseDto> AddPaymentAsync(CreatePaymentDto dto)
    {
        if (dto.Amount <= 0)
            throw new BusinessException("Payment amount must be greater than zero.");

        await using var transaction = _db.Database.IsRelational()
            ? await _db.Database.BeginTransactionAsync()
            : null;

        // Serialize all financial mutations for one invoice. Without this lock,
        // two concurrent payments can both pass the remaining-balance check.
        await AcquireAdvisoryLockAsync(transaction, 30, dto.InvoiceId);

        var invoice = await _db.Invoices
            .Include(x => x.Payments)
            .Include(x => x.Installments)
            .FirstOrDefaultAsync(x => x.Id == dto.InvoiceId)
            ?? throw new BusinessException("Invoice not found.");

        if (invoice.Status == InvoiceStatus.Cancelled)
            throw new BusinessException("Cancelled invoices cannot receive payments.");

        if (invoice.Status == InvoiceStatus.Draft)
            throw new BusinessException("Draft invoices cannot receive payments. Issue the invoice first.");

        var recordedPayments = invoice.Payments.Sum(x => x.Amount);
        if (Math.Abs(recordedPayments - invoice.PaidAmount) > 0.01m)
            invoice.PaidAmount = recordedPayments;

        var paymentDate = DateTimeUtility.ToUtc(dto.PaymentDate ?? DateTime.UtcNow);
        if (paymentDate < invoice.IssueDate)
            throw new BusinessException("Payment date cannot be earlier than the invoice issue date.");

        var remaining = invoice.Total - invoice.PaidAmount;
        if (dto.Amount > remaining + 0.01m)
            throw new BusinessException("Payment exceeds the invoice remaining amount.");

        var payment = new Payment
        {
            InvoiceId = invoice.Id, Amount = dto.Amount, PaymentDate = paymentDate,
            Method = dto.Method, Reference = Clean(dto.Reference), Notes = Clean(dto.Notes),
            ReceivedByUserId = _currentUser.UserId, CreatedAt = DateTime.UtcNow
        };

        _db.Payments.Add(payment);
        invoice.PaidAmount += payment.Amount;
        AllocatePaymentToInstallments(invoice, payment.Amount);
        UpdateInvoiceStatus(invoice);
        invoice.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        await _activity.CreateAsync(_currentUser.UserId, "Create", "Payment", payment.Id,
            $"Payment recorded for invoice {invoice.InvoiceNumber}.");

        if (transaction != null)
            await transaction.CommitAsync();

        await _db.Entry(payment).Reference(x => x.ReceivedByUser).LoadAsync();
        return MapPayment(payment);
    }

    public async Task<List<PaymentResponseDto>> GetPaymentsAsync(int? invoiceId = null)
    {
        var query = _db.Payments.AsNoTracking().Include(x => x.Invoice).Include(x => x.ReceivedByUser).AsQueryable();
        if (invoiceId.HasValue) query = query.Where(x => x.InvoiceId == invoiceId.Value);
        return (await query.OrderByDescending(x => x.PaymentDate).ToListAsync()).Select(MapPayment).ToList();
    }

    public async Task<InstallmentResponseDto> AddInstallmentAsync(InstallmentDto dto)
    {
        if (dto.Amount <= 0)
            throw new BusinessException("Installment amount must be greater than zero.");

        await using var transaction = _db.Database.IsRelational()
            ? await _db.Database.BeginTransactionAsync()
            : null;

        // Installments consume the same invoice financial capacity as payments,
        // so they must serialize with payment/installment mutations.
        await AcquireAdvisoryLockAsync(transaction, 30, dto.InvoiceId);

        var invoice = await _db.Invoices
            .Include(x => x.Installments)
            .FirstOrDefaultAsync(x => x.Id == dto.InvoiceId)
            ?? throw new BusinessException("Invoice not found.");

        if (invoice.Status == InvoiceStatus.Cancelled)
            throw new BusinessException("Cancelled invoices cannot receive installments.");

        if (invoice.Status == InvoiceStatus.Paid)
            throw new BusinessException("Paid invoices cannot receive new installments.");

        var dueDate = DateTimeUtility.ToUtc(dto.DueDate);
        if (dueDate < invoice.IssueDate)
            throw new BusinessException("Installment due date cannot be earlier than the invoice issue date.");

        var planned = invoice.Installments.Sum(x => x.Amount) + dto.Amount;
        if (planned > invoice.Total + 0.01m)
            throw new BusinessException("Installments exceed invoice total.");

        var installment = new Installment
        {
            InvoiceId = invoice.Id, DueDate = dueDate, Amount = dto.Amount,
            PaidAmount = 0, Status = invoice.Status == InvoiceStatus.Draft
                ? InvoiceStatus.Draft
                : InvoiceStatus.Issued
        };

        _db.Installments.Add(installment);
        await _db.SaveChangesAsync();

        if (transaction != null)
            await transaction.CommitAsync();

        return new InstallmentResponseDto
        {
            Id = installment.Id, InvoiceId = installment.InvoiceId, DueDate = installment.DueDate,
            Amount = installment.Amount, PaidAmount = 0, Status = installment.Status
        };
    }

    public async Task<List<InstallmentResponseDto>> GetInstallmentsAsync(int invoiceId)
    {
        var rows = await _db.Installments.AsNoTracking()
            .Where(x => x.InvoiceId == invoiceId)
            .OrderBy(x => x.DueDate)
            .ToListAsync();

        return rows.Select(x => new InstallmentResponseDto
        {
            Id = x.Id,
            InvoiceId = x.InvoiceId,
            DueDate = x.DueDate,
            Amount = x.Amount,
            PaidAmount = x.PaidAmount,
            Status = x.PaidAmount >= x.Amount
                ? InvoiceStatus.Paid
                : x.DueDate < DateTime.UtcNow
                    ? InvoiceStatus.Overdue
                    : x.PaidAmount > 0
                        ? InvoiceStatus.PartiallyPaid
                        : InvoiceStatus.Issued
        }).ToList();
    }

    private static void UpdateInvoiceStatus(Invoice invoice)
    {
        if (invoice.Status == InvoiceStatus.Cancelled) return;
        if (invoice.PaidAmount >= invoice.Total) invoice.Status = InvoiceStatus.Paid;
        else if (invoice.PaidAmount > 0) invoice.Status = InvoiceStatus.PartiallyPaid;
        else if (invoice.DueDate.HasValue && invoice.DueDate.Value < DateTime.UtcNow && invoice.Status != InvoiceStatus.Draft) invoice.Status = InvoiceStatus.Overdue;
        else if (invoice.Status == InvoiceStatus.Draft) invoice.Status = InvoiceStatus.Draft;
        else invoice.Status = InvoiceStatus.Issued;
    }

    private static InvoiceResponseDto Map(Invoice x) => new()
    {
        Id = x.Id, InvoiceNumber = x.InvoiceNumber, CustomerId = x.CustomerId, CustomerName = x.Customer.Name,
        ProjectId = x.ProjectId, QuotationId = x.QuotationId, IssueDate = x.IssueDate, DueDate = x.DueDate, Status = GetEffectiveStatus(x),
        Subtotal = x.Subtotal, Tax = x.Tax, Total = x.Total, PaidAmount = x.PaidAmount, Notes = x.Notes,
        Items = x.Items.OrderBy(i => i.SortOrder).Select(i => new InvoiceItemResponseDto { Id = i.Id, ProductComponentId = i.ProductComponentId, Description = i.Description, Quantity = i.Quantity, Unit = i.Unit, UnitPrice = i.UnitPrice, Total = i.Total, SortOrder = i.SortOrder }).ToList(),
        Installments = x.Installments.OrderBy(i => i.DueDate).Select(MapInstallment).ToList()
    };

    private static InstallmentResponseDto MapInstallment(Installment x) => new()
    {
        Id = x.Id, InvoiceId = x.InvoiceId, DueDate = x.DueDate, Amount = x.Amount, PaidAmount = x.PaidAmount, Status = x.Status
    };

    private static InvoiceStatus GetEffectiveStatus(Invoice invoice)
    {
        if (invoice.Status == InvoiceStatus.Cancelled || invoice.Status == InvoiceStatus.Draft)
            return invoice.Status;

        if (invoice.PaidAmount >= invoice.Total)
            return InvoiceStatus.Paid;

        if (invoice.PaidAmount > 0)
            return InvoiceStatus.PartiallyPaid;

        if (invoice.DueDate.HasValue && invoice.DueDate.Value < DateTime.UtcNow)
            return InvoiceStatus.Overdue;

        return InvoiceStatus.Issued;
    }

    private static void AllocatePaymentToInstallments(Invoice invoice, decimal paymentAmount)
    {
        var remainingPayment = paymentAmount;
        foreach (var installment in invoice.Installments.OrderBy(x => x.DueDate))
        {
            if (remainingPayment <= 0) break;
            var installmentRemaining = installment.Amount - installment.PaidAmount;
            if (installmentRemaining <= 0) continue;
            var applied = Math.Min(remainingPayment, installmentRemaining);
            installment.PaidAmount += applied;
            remainingPayment -= applied;
            installment.Status = installment.PaidAmount >= installment.Amount
                ? InvoiceStatus.Paid
                : InvoiceStatus.PartiallyPaid;
        }
    }

    private static PaymentResponseDto MapPayment(Payment x) => new()
    {
        Id = x.Id, InvoiceId = x.InvoiceId, InvoiceNumber = x.Invoice?.InvoiceNumber ?? string.Empty, Amount = x.Amount,
        PaymentDate = x.PaymentDate, Method = x.Method, Reference = x.Reference, Notes = x.Notes,
        ReceivedByUserId = x.ReceivedByUserId, ReceivedByUserName = x.ReceivedByUser?.FullName ?? string.Empty
    };

    private async Task AcquireAdvisoryLockAsync(
        Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction? transaction,
        int resourceType,
        int resourceId)
    {
        if (transaction == null)
            return;

        await _db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT pg_advisory_xact_lock({resourceType}, {resourceId});");
    }

    private static string GenerateNumber(string prefix) => $"{prefix}-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString("N")[..6].ToUpperInvariant()}";
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}

public class PurchaseOrderService : IPurchaseOrderService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUserService _currentUser;
    private readonly IActivityLogService _activity;

    public PurchaseOrderService(AppDbContext db, ICurrentUserService currentUser, IActivityLogService activity)
    {
        _db = db; _currentUser = currentUser; _activity = activity;
    }

    public async Task<List<PurchaseOrderResponseDto>> GetAllAsync() =>
        (await _db.PurchaseOrders.AsNoTracking().Include(x => x.Supplier).Include(x => x.Items).ThenInclude(x => x.ProductComponent)
            .OrderByDescending(x => x.OrderDate).ThenByDescending(x => x.Id).ToListAsync()).Select(Map).ToList();

    public async Task<PurchaseOrderResponseDto?> GetByIdAsync(int id)
    {
        var entity = await _db.PurchaseOrders.AsNoTracking().Include(x => x.Supplier).Include(x => x.Items).ThenInclude(x => x.ProductComponent).SingleOrDefaultAsync(x => x.Id == id);
        return entity == null ? null : Map(entity);
    }

    public async Task<PurchaseOrderResponseDto> CreateAsync(CreatePurchaseOrderDto dto)
    {
        var orderDate = DateTimeUtility.ToUtc(dto.OrderDate ?? DateTime.UtcNow);
        var expectedDeliveryDate = DateTimeUtility.ToUtc(dto.ExpectedDeliveryDate);
        if (expectedDeliveryDate.HasValue && expectedDeliveryDate.Value < orderDate)
            throw new BusinessException("Expected delivery date cannot be earlier than the order date.");

        if (!await _db.Suppliers.AnyAsync(x => x.Id == dto.SupplierId && x.IsActive)) throw new BusinessException("Supplier not found or inactive.");
        var entity = new PurchaseOrder
        {
            OrderNumber = $"PO-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString("N")[..6].ToUpperInvariant()}", SupplierId = dto.SupplierId,
            OrderDate = orderDate,
            ExpectedDeliveryDate = expectedDeliveryDate,
            Status = PurchaseOrderStatus.Ordered, Tax = dto.Tax, Notes = Clean(dto.Notes), CreatedByUserId = _currentUser.UserId,
            CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow
        };
        foreach (var item in dto.Items)
        {
            var product = await _db.ProductComponents.FirstOrDefaultAsync(x => x.Id == item.ProductComponentId && x.IsActive) ?? throw new BusinessException("One of the selected products is inactive or missing.");
            entity.Items.Add(new PurchaseOrderItem { ProductComponentId = product.Id, Quantity = item.Quantity, UnitCost = item.UnitCost, Total = Math.Round(item.Quantity * item.UnitCost, 2) });
        }
        entity.Subtotal = entity.Items.Sum(x => x.Total); entity.Total = entity.Subtotal + entity.Tax;
        _db.PurchaseOrders.Add(entity); await _db.SaveChangesAsync();
        await _activity.CreateAsync(_currentUser.UserId, "Create", "PurchaseOrder", entity.Id, $"Purchase order {entity.OrderNumber} created.");
        return (await GetByIdAsync(entity.Id))!;
    }

    public async Task<PurchaseOrderResponseDto?> ReceiveAsync(int id, ReceivePurchaseOrderDto dto)
    {
        if (dto.Items == null || dto.Items.Count == 0)
            throw new BusinessException("At least one purchase order item must be received.");

        if (dto.Items.Any(x => x.Quantity <= 0))
            throw new BusinessException("Received quantities must be greater than zero.");

        if (dto.Items.GroupBy(x => x.PurchaseOrderItemId).Any(g => g.Count() > 1))
            throw new BusinessException("A purchase order item cannot appear more than once in the same receipt.");

        await using var transaction = _db.Database.IsRelational()
            ? await _db.Database.BeginTransactionAsync()
            : null;

        // Lock the PO for the duration of the receipt operation. This prevents
        // concurrent receipts from validating against the same stale
        // ReceivedQuantity.
        await AcquireAdvisoryLockAsync(transaction, 20, id);

        var entity = await _db.PurchaseOrders
            .Include(x => x.Items)
            .ThenInclude(x => x.ProductComponent)
            .FirstOrDefaultAsync(x => x.Id == id);

        if (entity == null)
        {
            if (transaction != null)
                await transaction.RollbackAsync();
            return null;
        }

        if (entity.Status == PurchaseOrderStatus.Cancelled)
            throw new BusinessException("Cancelled purchase orders cannot be received.");

        // All inventory mutations use the same product-scoped lock as manual
        // adjustments. Acquire locks in deterministic order to avoid deadlocks.
        var productIds = dto.Items
            .Select(received => entity.Items.FirstOrDefault(i => i.Id == received.PurchaseOrderItemId)?.ProductComponentId)
            .Where(x => x.HasValue)
            .Select(x => x!.Value)
            .Distinct()
            .OrderBy(x => x)
            .ToList();

        foreach (var productId in productIds)
            await AcquireAdvisoryLockAsync(transaction, 1, productId);

        foreach (var received in dto.Items)
        {
            var item = entity.Items.FirstOrDefault(x => x.Id == received.PurchaseOrderItemId);
            if (item == null)
                throw new BusinessException($"Purchase order item {received.PurchaseOrderItemId} not found.");

            var remaining = item.Quantity - item.ReceivedQuantity;
            if (received.Quantity > remaining + 0.0001m)
                throw new BusinessException($"Received quantity exceeds remaining quantity for {item.ProductComponent.Name}.");

            var stock = await _db.InventoryStocks
                .FirstOrDefaultAsync(x => x.ProductComponentId == item.ProductComponentId);

            if (stock == null)
            {
                stock = new InventoryStock
                {
                    ProductComponentId = item.ProductComponentId,
                    QuantityOnHand = 0,
                    ReorderLevel = 0,
                    UpdatedAt = DateTime.UtcNow
                };
                _db.InventoryStocks.Add(stock);
            }

            stock.QuantityOnHand += received.Quantity;
            stock.UpdatedAt = DateTime.UtcNow;
            item.ReceivedQuantity += received.Quantity;

            _db.StockMovements.Add(new StockMovement
            {
                ProductComponentId = item.ProductComponentId,
                Type = StockMovementType.PurchaseReceipt,
                Quantity = received.Quantity,
                ReferenceType = "PurchaseOrder",
                ReferenceId = entity.Id,
                Notes = $"Receipt from {entity.OrderNumber}",
                CreatedByUserId = _currentUser.UserId,
                CreatedAt = DateTime.UtcNow
            });
        }

        var allReceived = entity.Items.All(x => x.ReceivedQuantity >= x.Quantity);
        var anyReceived = entity.Items.Any(x => x.ReceivedQuantity > 0);
        entity.Status = allReceived
            ? PurchaseOrderStatus.Received
            : anyReceived
                ? PurchaseOrderStatus.PartiallyReceived
                : entity.Status;
        entity.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        if (transaction != null)
            await transaction.CommitAsync();

        await _activity.CreateAsync(_currentUser.UserId, "Receive", "PurchaseOrder", id,
            $"Purchase order {entity.OrderNumber} received into inventory.");
        return await GetByIdAsync(id);
    }

    private async Task AcquireAdvisoryLockAsync(
        Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction? transaction,
        int resourceType,
        int resourceId)
    {
        if (transaction == null)
            return;

        await _db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT pg_advisory_xact_lock({resourceType}, {resourceId});");
    }

    private static PurchaseOrderResponseDto Map(PurchaseOrder x) => new()
    {
        Id = x.Id, OrderNumber = x.OrderNumber, SupplierId = x.SupplierId, SupplierName = x.Supplier.Name, OrderDate = x.OrderDate,
        ExpectedDeliveryDate = x.ExpectedDeliveryDate, Status = x.Status, Subtotal = x.Subtotal, Tax = x.Tax, Total = x.Total, Notes = x.Notes,
        Items = x.Items.OrderBy(i => i.Id).Select(i => new PurchaseOrderItemResponseDto { Id = i.Id, ProductComponentId = i.ProductComponentId, ProductName = i.ProductComponent.Name, Quantity = i.Quantity, ReceivedQuantity = i.ReceivedQuantity, UnitCost = i.UnitCost, Total = i.Total }).ToList()
    };
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}

public class InventoryService : IInventoryService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUserService _currentUser;
    private readonly IActivityLogService _activity;

    public InventoryService(AppDbContext db, ICurrentUserService currentUser, IActivityLogService activity)
    {
        _db = db; _currentUser = currentUser; _activity = activity;
    }

    public async Task<List<InventoryItemResponseDto>> GetAllAsync(bool lowStockOnly = false)
    {
        var rows = await _db.ProductComponents.AsNoTracking().Where(x => x.IsActive).Include(x => x.InventoryStock)
            .OrderBy(x => x.Name).ToListAsync();
        var result = rows.Select(x => new InventoryItemResponseDto
        {
            ProductComponentId = x.Id, Code = x.Code, ProductName = x.Name, Unit = x.Unit,
            QuantityOnHand = x.InventoryStock?.QuantityOnHand ?? 0, ReorderLevel = x.InventoryStock?.ReorderLevel ?? 0
        }).ToList();
        return lowStockOnly ? result.Where(x => x.IsLowStock).ToList() : result;
    }

    public async Task<List<StockMovementResponseDto>> GetMovementsAsync(int? productComponentId = null)
    {
        var query = _db.StockMovements.AsNoTracking().Include(x => x.ProductComponent).Include(x => x.CreatedByUser).AsQueryable();
        if (productComponentId.HasValue) query = query.Where(x => x.ProductComponentId == productComponentId.Value);
        return (await query.OrderByDescending(x => x.CreatedAt).Take(200).ToListAsync()).Select(x => new StockMovementResponseDto
        {
            Id = x.Id, ProductComponentId = x.ProductComponentId, ProductName = x.ProductComponent.Name, Type = x.Type,
            Quantity = x.Quantity, ReferenceType = x.ReferenceType, ReferenceId = x.ReferenceId, Notes = x.Notes,
            CreatedByUserName = x.CreatedByUser.FullName, CreatedAt = x.CreatedAt
        }).ToList();
    }

    public async Task<InventoryItemResponseDto?> AdjustAsync(InventoryAdjustmentDto dto)
    {
        if (dto.Quantity <= 0)
            throw new BusinessException("Adjustment quantity must be greater than zero.");

        await using var transaction = _db.Database.IsRelational()
            ? await _db.Database.BeginTransactionAsync()
            : null;

        // Use the same product-scoped lock as PO receipts. This makes manual
        // adjustments and purchase receipts serialize on the same stock item.
        await AcquireAdvisoryLockAsync(transaction, 1, dto.ProductComponentId);

        var product = await _db.ProductComponents
            .FirstOrDefaultAsync(x => x.Id == dto.ProductComponentId && x.IsActive);
        if (product == null)
            return null;

        var stock = await _db.InventoryStocks
            .FirstOrDefaultAsync(x => x.ProductComponentId == dto.ProductComponentId);
        if (stock == null)
        {
            stock = new InventoryStock
            {
                ProductComponentId = dto.ProductComponentId,
                QuantityOnHand = 0,
                ReorderLevel = 0,
                UpdatedAt = DateTime.UtcNow
            };
            _db.InventoryStocks.Add(stock);
        }

        if (!dto.Increase && stock.QuantityOnHand < dto.Quantity)
            throw new BusinessException("Stock cannot become negative.");

        stock.QuantityOnHand += dto.Increase ? dto.Quantity : -dto.Quantity;
        stock.UpdatedAt = DateTime.UtcNow;

        _db.StockMovements.Add(new StockMovement
        {
            ProductComponentId = dto.ProductComponentId,
            Type = dto.Increase ? StockMovementType.AdjustmentIn : StockMovementType.AdjustmentOut,
            Quantity = dto.Quantity,
            ReferenceType = "ManualAdjustment",
            Notes = dto.Notes?.Trim(),
            CreatedByUserId = _currentUser.UserId,
            CreatedAt = DateTime.UtcNow
        });

        await _db.SaveChangesAsync();

        if (transaction != null)
            await transaction.CommitAsync();

        await _activity.CreateAsync(_currentUser.UserId, "Adjust", "Inventory", dto.ProductComponentId,
            $"Inventory adjusted for {product.Name}.");

        return new InventoryItemResponseDto
        {
            ProductComponentId = product.Id, Code = product.Code, ProductName = product.Name,
            Unit = product.Unit, QuantityOnHand = stock.QuantityOnHand, ReorderLevel = stock.ReorderLevel
        };
    }

    public async Task<InventoryItemResponseDto?> SetReorderLevelAsync(int productComponentId, SetReorderLevelDto dto)
    {
        if (dto.ReorderLevel < 0)
            throw new BusinessException("Reorder level cannot be negative.");

        await using var transaction = _db.Database.IsRelational()
            ? await _db.Database.BeginTransactionAsync()
            : null;

        await AcquireAdvisoryLockAsync(transaction, 1, productComponentId);

        var product = await _db.ProductComponents
            .FirstOrDefaultAsync(x => x.Id == productComponentId && x.IsActive);
        if (product == null)
            return null;

        var stock = await _db.InventoryStocks
            .FirstOrDefaultAsync(x => x.ProductComponentId == productComponentId);
        if (stock == null)
        {
            stock = new InventoryStock
            {
                ProductComponentId = productComponentId,
                QuantityOnHand = 0,
                ReorderLevel = dto.ReorderLevel,
                UpdatedAt = DateTime.UtcNow
            };
            _db.InventoryStocks.Add(stock);
        }
        else
        {
            stock.ReorderLevel = dto.ReorderLevel;
            stock.UpdatedAt = DateTime.UtcNow;
        }

        await _db.SaveChangesAsync();

        if (transaction != null)
            await transaction.CommitAsync();

        return new InventoryItemResponseDto
        {
            ProductComponentId = product.Id, Code = product.Code, ProductName = product.Name,
            Unit = product.Unit, QuantityOnHand = stock.QuantityOnHand, ReorderLevel = stock.ReorderLevel
        };
    }

    private async Task AcquireAdvisoryLockAsync(
        Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction? transaction,
        int resourceType,
        int resourceId)
    {
        if (transaction == null)
            return;

        await _db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT pg_advisory_xact_lock({resourceType}, {resourceId});");
    }

}
