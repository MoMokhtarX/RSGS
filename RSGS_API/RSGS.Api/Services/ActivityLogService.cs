using RSGS.Api.Common;
using RSGS.Api.DTOs.ActivityLogs;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Repositories.Interfaces;

namespace RSGS.Api.Services;

public class ActivityLogService : IActivityLogService
{
    private readonly IActivityLogRepository _repository;

    public ActivityLogService(
        IActivityLogRepository repository)
    {
        _repository = repository;
    }

    public async Task<ActivityLog> CreateAsync(
        int userId,
        string action,
        string entity,
        int entityId,
        string description)
    {
        var log = new ActivityLog
        {
            UserId = userId,
            Action = action,
            Entity = entity,
            EntityId = entityId,
            Description = description,
            CreatedAt = DateTime.UtcNow
        };

        await _repository.AddAsync(log);

        return log;
    }

    public async Task<List<ActivityLog>> GetRecentAsync(int count = 50)
    {
        return await _repository.GetRecentAsync(count);
    }

    public async Task<PagedResult<ActivityLogDto>> SearchAsync(
        ActivityLogQueryParameters parameters)
    {
        return await _repository.SearchAsync(parameters);
    }
}