using Microsoft.EntityFrameworkCore;
using RSGS.Api.Common;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Services;

public interface IPagedListService
{
    Task<PagedResult<ProjectListItemDto>> GetProjectsAsync(ProjectQueryParameters parameters, int? engineerId);
    Task<PagedResult<QuotationResponseDto>> GetQuotationsAsync(QuotationQueryParameters parameters, int? engineerId);
}

public class PagedListService : IPagedListService
{
    private readonly AppDbContext _db;
    public PagedListService(AppDbContext db) => _db = db;

    public async Task<PagedResult<ProjectListItemDto>> GetProjectsAsync(ProjectQueryParameters p, int? engineerId)
    {
        var query = _db.Projects.AsNoTracking().Include(x => x.Customer).Include(x => x.Engineer).AsQueryable();
        if (engineerId.HasValue) query = query.Where(x => x.EngineerId == engineerId.Value);
        if (p.EngineerId.HasValue && !engineerId.HasValue) query = query.Where(x => x.EngineerId == p.EngineerId.Value);
        if (!string.IsNullOrWhiteSpace(p.Search))
        {
            var q = p.Search.Trim();
            var pattern = $"%{q}%";
            query = query.Where(x =>
                EF.Functions.ILike(x.Name, pattern) ||
                EF.Functions.ILike(x.ProjectNumber, pattern) ||
                EF.Functions.ILike(x.Customer.Name, pattern));
        }
        if (!string.IsNullOrWhiteSpace(p.Status) && Enum.TryParse<ProjectStatus>(p.Status, true, out var status)) query = query.Where(x => x.Status == status);
        query = p.SortBy?.ToLower() switch
        {
            "name" => p.Descending ? query.OrderByDescending(x => x.Name) : query.OrderBy(x => x.Name),
            "value" => p.Descending ? query.OrderByDescending(x => x.TotalValue) : query.OrderBy(x => x.TotalValue),
            "date" => p.Descending ? query.OrderByDescending(x => x.CreatedDate) : query.OrderBy(x => x.CreatedDate),
            _ => p.Descending ? query.OrderByDescending(x => x.Id) : query.OrderBy(x => x.Id)
        };
        var total = await query.CountAsync();
        var rows = await query.Skip((p.PageNumber - 1) * p.PageSize).Take(p.PageSize).Select(x => new ProjectListItemDto
        {
            Id = x.Id, ProjectNumber = x.ProjectNumber, Name = x.Name, CustomerId = x.CustomerId,
            CustomerName = x.Customer.Name, CustomerChannel = x.Customer.Channel, EngineerId = x.EngineerId,
            EngineerName = x.Engineer != null ? x.Engineer.FullName : null, Status = x.Status,
            CreatedDate = x.CreatedDate, InstallationDate = x.InstallationDate, Notes = x.Notes,
            TotalValue = x.TotalValue, TotalKW = x.TotalKw, Address = x.Address, Governorate = x.Governorate,
            City = x.City, Latitude = x.Latitude, Longitude = x.Longitude
        }).ToListAsync();
        return new PagedResult<ProjectListItemDto> { Items = rows, PageNumber = p.PageNumber, PageSize = p.PageSize, TotalCount = total };
    }

    public async Task<PagedResult<QuotationResponseDto>> GetQuotationsAsync(QuotationQueryParameters p, int? engineerId)
    {
        var query = _db.Quotations.AsNoTracking().Include(x => x.Customer).Include(x => x.Project).Include(x => x.Items.OrderBy(i => i.SortOrder)).AsQueryable();
        if (engineerId.HasValue) query = query.Where(x => (x.ProjectId.HasValue && x.Project!.EngineerId == engineerId.Value) || x.Customer!.AssignedUserId == engineerId.Value);
        if (p.CustomerId.HasValue) query = query.Where(x => x.CustomerId == p.CustomerId.Value);
        if (p.ProjectId.HasValue) query = query.Where(x => x.ProjectId == p.ProjectId.Value);
        if (!string.IsNullOrWhiteSpace(p.Search))
        {
            var q = p.Search.Trim();
            var pattern = $"%{q}%";
            query = query.Where(x => EF.Functions.ILike(x.QuotationNumber, pattern));
        }
        if (!string.IsNullOrWhiteSpace(p.Status) && Enum.TryParse<QuotationStatus>(p.Status, true, out var status)) query = query.Where(x => x.Status == status);
        if (!string.IsNullOrWhiteSpace(p.Type) && Enum.TryParse<QuotationType>(p.Type, true, out var type)) query = query.Where(x => x.Type == type);
        query = p.SortBy?.ToLower() switch
        {
            "number" => p.Descending ? query.OrderByDescending(x => x.QuotationNumber) : query.OrderBy(x => x.QuotationNumber),
            "price" => p.Descending ? query.OrderByDescending(x => x.TotalPrice) : query.OrderBy(x => x.TotalPrice),
            "date" => p.Descending ? query.OrderByDescending(x => x.QuotationDate) : query.OrderBy(x => x.QuotationDate),
            _ => p.Descending ? query.OrderByDescending(x => x.Id) : query.OrderBy(x => x.Id)
        };
        var total = await query.CountAsync();
        var rows = await query.Skip((p.PageNumber - 1) * p.PageSize).Take(p.PageSize).ToListAsync();
        var result = rows.Select(x => new QuotationResponseDto
        {
            Id = x.Id, QuotationNumber = x.QuotationNumber, Type = x.Type, Status = x.Status,
            CustomerId = x.CustomerId, ProjectId = x.ProjectId, QuotationDate = x.QuotationDate, ValidUntil = x.ValidUntil,
            SystemDescription = x.SystemDescription, SystemCapacity = x.SystemCapacity, CapacityUnit = x.CapacityUnit,
            TotalPrice = x.TotalPrice, MaterialsCost = x.MaterialsCost, TransportationCost = x.TransportationCost,
            InstallationCost = x.InstallationCost, OtherCost = x.OtherCost, ProfitMargin = x.ProfitMargin,
            Discount = x.Discount, Tax = x.Tax, Introduction = x.Introduction, GeneralTerms = x.GeneralTerms,
            PaymentTerms = x.PaymentTerms, Notes = x.Notes,
            SentAt = x.SentAt, SentByUserId = x.SentByUserId, SentMethod = x.SentMethod, SentRecipient = x.SentRecipient,
            Items = x.Items.OrderBy(i => i.SortOrder).Select(i => new QuotationItemResponseDto
            {
                Id = i.Id, Description = i.Description, Item = i.Item, Category = i.Category, Quantity = i.Quantity,
                Unit = i.Unit, CountryOfOrigin = i.CountryOfOrigin, SortOrder = i.SortOrder, InternalNotes = i.InternalNotes
            }).ToList()
        }).ToList();
        return new PagedResult<QuotationResponseDto> { Items = result, PageNumber = p.PageNumber, PageSize = p.PageSize, TotalCount = total };
    }
}
