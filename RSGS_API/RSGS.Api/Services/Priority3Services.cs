using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Exceptions;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Utilities;

namespace RSGS.Api.Services;

public class CustomerActivityService : ICustomerActivityService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUserService _currentUser;
    private readonly IActivityLogService _activity;

    public CustomerActivityService(AppDbContext db, ICurrentUserService currentUser, IActivityLogService activity)
    {
        _db = db;
        _currentUser = currentUser;
        _activity = activity;
    }

    public async Task<List<CustomerFollowUpResponseDto>> GetFollowUpsAsync(int customerId)
    {
        await EnsureCustomerAccessAsync(customerId);
        return await _db.CustomerFollowUps
            .AsNoTracking()
            .Include(x => x.User)
            .Where(x => x.CustomerId == customerId)
            .OrderBy(x => x.ScheduledAt)
            .Select(x => new CustomerFollowUpResponseDto
            {
                Id = x.Id, CustomerId = x.CustomerId, UserId = x.UserId,
                UserName = x.User.FullName, Type = x.Type, ScheduledAt = x.ScheduledAt,
                CompletedAt = x.CompletedAt, Status = x.Status, Notes = x.Notes, CreatedAt = x.CreatedAt
            }).ToListAsync();
    }

    public async Task<CustomerFollowUpResponseDto> CreateFollowUpAsync(int customerId, CreateCustomerFollowUpDto dto)
    {
        await EnsureCustomerAccessAsync(customerId);
        var ownsTransaction = _db.Database.CurrentTransaction == null && _db.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _db.Database.BeginTransactionAsync()
            : null;
        var entity = new CustomerFollowUp
        {
            CustomerId = customerId, UserId = _currentUser.UserId, Type = dto.Type.Trim(),
            ScheduledAt = DateTimeUtility.ToUtc(dto.ScheduledAt),
            Status = string.IsNullOrWhiteSpace(dto.Status) ? "Pending" : dto.Status.Trim(),
            Notes = dto.Notes?.Trim(), CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow
        };
        _db.CustomerFollowUps.Add(entity);
        await _db.SaveChangesAsync();
        await _activity.CreateAsync(_currentUser.UserId, "Create", "CustomerFollowUp", entity.Id, $"Follow-up created for customer {customerId}.");
        if (ownsTransaction)
            await transaction!.CommitAsync();

        return await MapFollowUpAsync(entity.Id);
    }

    public async Task<CustomerFollowUpResponseDto?> UpdateFollowUpAsync(int id, UpdateCustomerFollowUpDto dto)
    {
        var entity = await _db.CustomerFollowUps.FirstOrDefaultAsync(x => x.Id == id);
        if (entity == null) return null;
        var ownsTransaction = _db.Database.CurrentTransaction == null && _db.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _db.Database.BeginTransactionAsync()
            : null;
        await EnsureCustomerAccessAsync(entity.CustomerId);
        entity.Type = dto.Type.Trim(); entity.ScheduledAt = DateTimeUtility.ToUtc(dto.ScheduledAt);
        entity.Status = string.IsNullOrWhiteSpace(dto.Status) ? entity.Status : dto.Status.Trim();
        entity.Notes = dto.Notes?.Trim();
        entity.CompletedAt = dto.CompletedAt.HasValue ? DateTimeUtility.ToUtc(dto.CompletedAt.Value) : null;
        entity.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        await _activity.CreateAsync(_currentUser.UserId, "Update", "CustomerFollowUp", id, $"Follow-up {id} updated.");
        if (ownsTransaction)
            await transaction!.CommitAsync();

        return await MapFollowUpAsync(id);
    }

    public async Task<bool> DeleteFollowUpAsync(int id)
    {
        var entity = await _db.CustomerFollowUps.FirstOrDefaultAsync(x => x.Id == id);
        if (entity == null) return false;
        var ownsTransaction = _db.Database.CurrentTransaction == null && _db.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _db.Database.BeginTransactionAsync()
            : null;
        await EnsureCustomerAccessAsync(entity.CustomerId);
        _db.CustomerFollowUps.Remove(entity);
        await _db.SaveChangesAsync();
        await _activity.CreateAsync(_currentUser.UserId, "Delete", "CustomerFollowUp", id, $"Follow-up {id} deleted.");
        if (ownsTransaction)
            await transaction!.CommitAsync();

        return true;
    }

    public async Task<List<CustomerInteractionResponseDto>> GetInteractionsAsync(int customerId)
    {
        await EnsureCustomerAccessAsync(customerId);
        return await _db.CustomerInteractions
            .AsNoTracking().Include(x => x.User)
            .Where(x => x.CustomerId == customerId)
            .OrderByDescending(x => x.OccurredAt)
            .Select(x => new CustomerInteractionResponseDto
            {
                Id = x.Id, CustomerId = x.CustomerId, UserId = x.UserId,
                UserName = x.User.FullName, Type = x.Type, Subject = x.Subject,
                Details = x.Details, OccurredAt = x.OccurredAt, CreatedAt = x.CreatedAt
            }).ToListAsync();
    }

    public async Task<CustomerInteractionResponseDto> CreateInteractionAsync(int customerId, CreateCustomerInteractionDto dto)
    {
        await EnsureCustomerAccessAsync(customerId);
        var ownsTransaction = _db.Database.CurrentTransaction == null && _db.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _db.Database.BeginTransactionAsync()
            : null;
        var entity = new CustomerInteraction
        {
            CustomerId = customerId, UserId = _currentUser.UserId, Type = dto.Type.Trim(),
            Subject = dto.Subject?.Trim(), Details = dto.Details.Trim(),
            OccurredAt = dto.OccurredAt.HasValue ? DateTimeUtility.ToUtc(dto.OccurredAt.Value) : DateTime.UtcNow,
            CreatedAt = DateTime.UtcNow
        };
        _db.CustomerInteractions.Add(entity);
        await _db.SaveChangesAsync();
        await _activity.CreateAsync(_currentUser.UserId, "Create", "CustomerInteraction", entity.Id, $"Interaction added for customer {customerId}.");
        if (ownsTransaction)
            await transaction!.CommitAsync();

        return await MapInteractionAsync(entity.Id);
    }

    private async Task EnsureCustomerAccessAsync(int customerId)
    {
        var customer = await _db.Customers.AsNoTracking().FirstOrDefaultAsync(x => x.Id == customerId);
        if (customer == null) throw new BusinessException("Customer not found.");
        if (_currentUser.Role == UserRole.Engineer.ToString() && customer.AssignedUserId != _currentUser.UserId)
            throw new BusinessException("You can only access customers assigned to you.");
    }

    private Task<CustomerFollowUpResponseDto> MapFollowUpAsync(int id) => _db.CustomerFollowUps.Include(x => x.User)
        .Where(x => x.Id == id).Select(x => new CustomerFollowUpResponseDto
        {
            Id = x.Id, CustomerId = x.CustomerId, UserId = x.UserId, UserName = x.User.FullName,
            Type = x.Type, ScheduledAt = x.ScheduledAt, CompletedAt = x.CompletedAt, Status = x.Status,
            Notes = x.Notes, CreatedAt = x.CreatedAt
        }).SingleAsync();

    private Task<CustomerInteractionResponseDto> MapInteractionAsync(int id) => _db.CustomerInteractions.Include(x => x.User)
        .Where(x => x.Id == id).Select(x => new CustomerInteractionResponseDto
        {
            Id = x.Id, CustomerId = x.CustomerId, UserId = x.UserId, UserName = x.User.FullName,
            Type = x.Type, Subject = x.Subject, Details = x.Details, OccurredAt = x.OccurredAt, CreatedAt = x.CreatedAt
        }).SingleAsync();
}

public class GlobalSearchService : IGlobalSearchService
{
    private readonly AppDbContext _db;
    public GlobalSearchService(AppDbContext db) => _db = db;

    public async Task<List<GlobalSearchResultDto>> SearchAsync(string query, int? engineerId)
    {
        var q = query.Trim();
        if (q.Length < 2) return [];

        var customers = _db.Customers.AsNoTracking();
        var projects = _db.Projects.AsNoTracking();
        var quotations = _db.Quotations.AsNoTracking();

        if (engineerId.HasValue)
        {
            customers = customers.Where(x => x.AssignedUserId == engineerId.Value);
            projects = projects.Where(x => x.EngineerId == engineerId.Value);
            quotations = quotations.Where(x => (x.ProjectId.HasValue && x.Project!.EngineerId == engineerId.Value) || x.Customer!.AssignedUserId == engineerId.Value);
        }

        var pattern = $"%{q}%";

        // PostgreSQL should use ILIKE for case-insensitive search. The InMemory provider
        // used by unit tests does not translate ILIKE, so keep a provider-safe fallback.
        if (_db.Database.IsRelational())
        {
            var customerResults = await customers.Where(x => EF.Functions.ILike(x.Name, pattern) ||
                    (x.Phone != null && EF.Functions.ILike(x.Phone, pattern)) ||
                    (x.Email != null && EF.Functions.ILike(x.Email, pattern)))
                .OrderBy(x => x.Name).Take(20)
                .Select(x => new GlobalSearchResultDto { Type = "Customer", Id = x.Id, Title = x.Name, Subtitle = x.Phone, Route = $"/customers/{x.Id}" }).ToListAsync();

            var projectResults = await projects.Where(x => EF.Functions.ILike(x.Name, pattern) || EF.Functions.ILike(x.ProjectNumber, pattern))
                .OrderByDescending(x => x.Id).Take(20)
                .Select(x => new GlobalSearchResultDto { Type = "Project", Id = x.Id, Title = x.Name, Subtitle = x.ProjectNumber, Route = $"/projects/{x.Id}" }).ToListAsync();

            var quotationResults = await quotations.Where(x => EF.Functions.ILike(x.QuotationNumber, pattern))
                .OrderByDescending(x => x.Id).Take(20)
                .Select(x => new GlobalSearchResultDto { Type = "Quotation", Id = x.Id, Title = x.QuotationNumber, Subtitle = x.Status.ToString(), Route = $"/quotations/{x.Id}" }).ToListAsync();

            return customerResults.Concat(projectResults).Concat(quotationResults).Take(60).ToList();
        }

        var fallback = q.ToLowerInvariant();
        var customerFallback = await customers.Where(x => x.Name.ToLower().Contains(fallback) ||
                (x.Phone != null && x.Phone.ToLower().Contains(fallback)) ||
                (x.Email != null && x.Email.ToLower().Contains(fallback)))
            .OrderBy(x => x.Name).Take(20)
            .Select(x => new GlobalSearchResultDto { Type = "Customer", Id = x.Id, Title = x.Name, Subtitle = x.Phone, Route = $"/customers/{x.Id}" }).ToListAsync();
        var projectFallback = await projects.Where(x => x.Name.ToLower().Contains(fallback) || x.ProjectNumber.ToLower().Contains(fallback))
            .OrderByDescending(x => x.Id).Take(20)
            .Select(x => new GlobalSearchResultDto { Type = "Project", Id = x.Id, Title = x.Name, Subtitle = x.ProjectNumber, Route = $"/projects/{x.Id}" }).ToListAsync();
        var quotationFallback = await quotations.Where(x => x.QuotationNumber.ToLower().Contains(fallback))
            .OrderByDescending(x => x.Id).Take(20)
            .Select(x => new GlobalSearchResultDto { Type = "Quotation", Id = x.Id, Title = x.QuotationNumber, Subtitle = x.Status.ToString(), Route = $"/quotations/{x.Id}" }).ToListAsync();

        var customerResultsFallback = customerFallback;
        var projectResultsFallback = projectFallback;
        var quotationResultsFallback = quotationFallback;

        return customerResultsFallback.Concat(projectResultsFallback).Concat(quotationResultsFallback).Take(60).ToList();
    }
}

public class QuotationVersionService : IQuotationVersionService
{
    private readonly AppDbContext _db;
    public QuotationVersionService(AppDbContext db) => _db = db;

    public async Task CreateSnapshotAsync(Quotation quotation, int userId, string reason)
    {
        // VersionNumber is unique per quotation. MAX + 1 is unsafe under
        // concurrent updates, so serialize allocation for this quotation.
        var ownsTransaction = _db.Database.CurrentTransaction == null && _db.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _db.Database.BeginTransactionAsync()
            : null;

        if (_db.Database.IsRelational())
        {
            await _db.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock(40, {quotation.Id});");
        }

        var version = (await _db.QuotationVersions
            .Where(x => x.QuotationId == quotation.Id)
            .MaxAsync(x => (int?)x.VersionNumber) ?? 0) + 1;
        var snapshot = new
        {
            quotation.Id, quotation.QuotationNumber, quotation.Type, quotation.Status,
            quotation.CustomerId, quotation.ProjectId, quotation.QuotationDate, quotation.ValidUntil,
            quotation.SystemDescription, quotation.SystemCapacity, quotation.CapacityUnit,
            quotation.MaterialsCost, quotation.TransportationCost, quotation.InstallationCost, quotation.OtherCost,
            quotation.ProfitMargin, quotation.Discount, quotation.Tax, quotation.TotalPrice,
            quotation.Introduction, quotation.GeneralTerms, quotation.PaymentTerms, quotation.Notes,
            Items = quotation.Items.Select(i => new { i.Id, i.ProductComponentId, i.Description, i.Item, i.Category, i.Quantity, i.Unit, i.CountryOfOrigin, i.UnitCost, i.UnitPrice, i.TotalCost, i.TotalPrice, i.SortOrder, i.InternalNotes }).ToList()
        };
        _db.QuotationVersions.Add(new QuotationVersion
        {
            QuotationId = quotation.Id, VersionNumber = version, CreatedByUserId = userId,
            SnapshotJson = JsonSerializer.Serialize(snapshot), Reason = reason, CreatedAt = DateTime.UtcNow
        });
        await _db.SaveChangesAsync();

        if (ownsTransaction)
            await transaction!.CommitAsync();
    }

    public async Task<List<QuotationVersionResponseDto>> GetHistoryAsync(int quotationId)
    {
        var rows = await _db.QuotationVersions.AsNoTracking().Include(x => x.CreatedByUser)
            .Where(x => x.QuotationId == quotationId).OrderByDescending(x => x.VersionNumber).ToListAsync();
        return rows.Select(x => new QuotationVersionResponseDto
        {
            Id = x.Id, QuotationId = x.QuotationId, VersionNumber = x.VersionNumber,
            CreatedByUserId = x.CreatedByUserId, CreatedByUserName = x.CreatedByUser.FullName,
            Reason = x.Reason, CreatedAt = x.CreatedAt,
            Snapshot = JsonSerializer.Deserialize<object>(x.SnapshotJson)
        }).ToList();
    }
}
