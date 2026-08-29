using Microsoft.EntityFrameworkCore;
using RSGS.Api.Common;
using RSGS.Api.Data;
using RSGS.Api.DTOs.ActivityLogs;
using RSGS.Api.Models;
using RSGS.Api.Repositories.Interfaces;

namespace RSGS.Api.Repositories;

public class ActivityLogRepository
    : GenericRepository<ActivityLog>, IActivityLogRepository
{
    public ActivityLogRepository(AppDbContext context)
        : base(context)
    {
    }

    public async Task<List<ActivityLog>> GetRecentAsync(int count = 50)
    {
        return await _context.ActivityLogs
            .Include(a => a.User)
            .OrderByDescending(a => a.CreatedAt)
            .Take(count)
            .ToListAsync();
    }

    public async Task<PagedResult<ActivityLogDto>> SearchAsync(
        ActivityLogQueryParameters parameters)
    {
        var query = _context.ActivityLogs
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(parameters.Search))
        {
            query = query.Where(x =>
                x.Description.Contains(parameters.Search));
        }

        if (parameters.UserId.HasValue)
        {
            query = query.Where(x =>
                x.UserId == parameters.UserId.Value);
        }

        if (!string.IsNullOrWhiteSpace(parameters.Action))
        {
            query = query.Where(x =>
                x.Action == parameters.Action);
        }

        if (!string.IsNullOrWhiteSpace(parameters.Entity))
        {
            query = query.Where(x =>
                x.Entity == parameters.Entity);
        }

        if (parameters.From.HasValue)
        {
            query = query.Where(x =>
                x.CreatedAt >= parameters.From.Value);
        }

        if (parameters.To.HasValue)
        {
            query = query.Where(x =>
                x.CreatedAt <= parameters.To.Value);
        }

        query = parameters.Sort == "asc"
            ? query.OrderBy(x => x.CreatedAt)
            : query.OrderByDescending(x => x.CreatedAt);

        var total = await query.CountAsync();

        var data = await query
            .Skip((parameters.PageNumber - 1) * parameters.PageSize)
            .Take(parameters.PageSize)
            .Select(x => new ActivityLogDto
            {
                Id = x.Id,
                UserId = x.UserId,
                Username = x.User != null
                    ? x.User.Username
                    : null,
                FullName = x.User != null
                    ? x.User.FullName
                    : null,
                Action = x.Action,
                Entity = x.Entity,
                EntityId = x.EntityId,
                Description = x.Description,
                CreatedAt = x.CreatedAt
            })
            .ToListAsync();

        return new PagedResult<ActivityLogDto>
        {
            Items = data,
            TotalCount = total,
            PageNumber = parameters.PageNumber,
            PageSize = parameters.PageSize
        };
    }
}