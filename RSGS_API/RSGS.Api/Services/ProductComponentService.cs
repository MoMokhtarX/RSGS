using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Exceptions;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;

namespace RSGS.Api.Services;

public class ProductComponentService : IProductComponentService
{
    private readonly AppDbContext _context;
    private readonly IActivityLogService _activityLogService;
    private readonly ICurrentUserService _currentUser;
    private readonly IAuditService _auditService;

    public ProductComponentService(
        AppDbContext context,
        IActivityLogService activityLogService,
        ICurrentUserService currentUser,
        IAuditService auditService)
    {
        _context = context;
        _activityLogService = activityLogService;
        _currentUser = currentUser;
        _auditService = auditService;
    }

    public async Task<List<ProductComponentResponseDto>> GetAllAsync(
        string? search = null,
        QuotationItemCategory? category = null,
        bool activeOnly = false)
    {
        var query = _context.ProductComponents.AsNoTracking().AsQueryable();

        if (activeOnly)
            query = query.Where(x => x.IsActive);

        if (category.HasValue)
            query = query.Where(x => x.Category == category.Value);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            if (_context.Database.IsRelational())
            {
                var pattern = $"%{term}%";
                query = query.Where(x =>
                    EF.Functions.ILike(x.Code, pattern) ||
                    EF.Functions.ILike(x.Name, pattern) ||
                    (x.Brand != null && EF.Functions.ILike(x.Brand, pattern)) ||
                    (x.Model != null && EF.Functions.ILike(x.Model, pattern)));
            }
            else
            {
                var normalized = term.ToLowerInvariant();
                query = query.Where(x =>
                    x.Code.ToLower().Contains(normalized) ||
                    x.Name.ToLower().Contains(normalized) ||
                    (x.Brand != null && x.Brand.ToLower().Contains(normalized)) ||
                    (x.Model != null && x.Model.ToLower().Contains(normalized)));
            }
        }

        return await query
            .OrderBy(x => x.Category)
            .ThenBy(x => x.Name)
            .Select(MapExpression())
            .ToListAsync();
    }

    public async Task<ProductComponentResponseDto?> GetByIdAsync(int id)
    {
        return await _context.ProductComponents
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(MapExpression())
            .FirstOrDefaultAsync();
    }

    public async Task<ProductComponentResponseDto> CreateAsync(CreateProductComponentDto dto)
    {
        if (!Enum.IsDefined(dto.Category))
            throw new BusinessException("Invalid product category.");

        var code = dto.Code.Trim();

        if (await _context.ProductComponents.AnyAsync(x => x.Code.ToLower() == code.ToLower()))
            throw new BusinessException("Product code already exists.");

        if (dto.SellingPrice < dto.CostPrice)
            throw new BusinessException("Selling price cannot be lower than cost price.");

        var ownsTransaction = _context.Database.CurrentTransaction == null && _context.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _context.Database.BeginTransactionAsync()
            : null;

        var product = new ProductComponent
        {
            Code = code,
            Name = dto.Name.Trim(),
            Category = dto.Category,
            Brand = Clean(dto.Brand),
            Model = Clean(dto.Model),
            Specification = Clean(dto.Specification),
            Unit = dto.Unit.Trim(),
            CountryOfOrigin = Clean(dto.CountryOfOrigin),
            CostPrice = dto.CostPrice,
            SellingPrice = dto.SellingPrice,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.ProductComponents.Add(product);
        await _context.SaveChangesAsync();

        await _auditService.CreateAsync(
            _currentUser.UserId,
            "ProductComponent",
            product.Id,
            null,
            product,
            new[] { "Code", "Name", "Category", "Brand", "Model", "Unit", "CostPrice", "SellingPrice", "IsActive" });

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return Map(product);
    }

    public async Task<ProductComponentResponseDto?> UpdateAsync(
        int id,
        UpdateProductComponentDto dto)
    {
        var product = await _context.ProductComponents.FindAsync(id);
        if (product == null)
            return null;

        var ownsTransaction = _context.Database.CurrentTransaction == null && _context.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _context.Database.BeginTransactionAsync()
            : null;

        if (!Enum.IsDefined(dto.Category))
            throw new BusinessException("Invalid product category.");

        if (dto.SellingPrice < dto.CostPrice)
            throw new BusinessException("Selling price cannot be lower than cost price.");

        // Snapshot the persisted state before applying the update.
        var previous = new
        {
            product.Code,
            product.Name,
            product.Category,
            product.Brand,
            product.Model,
            product.Specification,
            product.Unit,
            product.CountryOfOrigin,
            product.CostPrice,
            product.SellingPrice,
            product.IsActive
        };

        product.Name = dto.Name.Trim();
        product.Category = dto.Category;
        product.Brand = Clean(dto.Brand);
        product.Model = Clean(dto.Model);
        product.Specification = Clean(dto.Specification);
        product.Unit = dto.Unit.Trim();
        product.CountryOfOrigin = Clean(dto.CountryOfOrigin);
        product.CostPrice = dto.CostPrice;
        product.SellingPrice = dto.SellingPrice;
        product.IsActive = dto.IsActive;

        product.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        await _auditService.UpdateAsync(
            _currentUser.UserId,
            "ProductComponent",
            product.Id,
            previous,
            product,
            new[] { "Code", "Name", "Category", "Brand", "Model", "Specification", "Unit", "CountryOfOrigin", "CostPrice", "SellingPrice", "IsActive" });

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return Map(product);
    }

    public async Task<bool> SetActiveAsync(int id, bool isActive)
    {
        var product = await _context.ProductComponents.FindAsync(id);
        if (product == null)
            return false;

        var ownsTransaction = _context.Database.CurrentTransaction == null && _context.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _context.Database.BeginTransactionAsync()
            : null;

        var previous = new { product.IsActive };

        product.IsActive = isActive;
        product.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        await _auditService.UpdateAsync(
            _currentUser.UserId,
            "ProductComponent",
            product.Id,
            previous,
            product,
            new[] { "IsActive" });

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return true;
    }

    private static string? Clean(string? value)
    {
        var text = value?.Trim();
        return string.IsNullOrWhiteSpace(text) ? null : text;
    }

    private static ProductComponentResponseDto Map(ProductComponent x) => new()
    {
        Id = x.Id,
        Code = x.Code,
        Name = x.Name,
        Category = x.Category,
        Brand = x.Brand,
        Model = x.Model,
        Specification = x.Specification,
        Unit = x.Unit,
        CountryOfOrigin = x.CountryOfOrigin,
        CostPrice = x.CostPrice,
        SellingPrice = x.SellingPrice,
        IsActive = x.IsActive,
        CreatedAt = x.CreatedAt,
        UpdatedAt = x.UpdatedAt
    };

    private static System.Linq.Expressions.Expression<Func<ProductComponent, ProductComponentResponseDto>> MapExpression()
        => x => new ProductComponentResponseDto
        {
            Id = x.Id,
            Code = x.Code,
            Name = x.Name,
            Category = x.Category,
            Brand = x.Brand,
            Model = x.Model,
            Specification = x.Specification,
            Unit = x.Unit,
            CountryOfOrigin = x.CountryOfOrigin,
            CostPrice = x.CostPrice,
            SellingPrice = x.SellingPrice,
            IsActive = x.IsActive,
            CreatedAt = x.CreatedAt,
            UpdatedAt = x.UpdatedAt
        };
}
