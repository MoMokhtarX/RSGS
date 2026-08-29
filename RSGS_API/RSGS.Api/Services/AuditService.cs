using System.Collections.Generic;
using RSGS.Api.Interfaces;
using RSGS.Api.Utilities;

namespace RSGS.Api.Services;

public class AuditService : IAuditService
{
    private readonly IActivityLogService _activityLogService;

    public AuditService(IActivityLogService activityLogService)
    {
        _activityLogService = activityLogService;
    }

    public async Task CreateAsync(int userId, string entity, int entityId, object? previous, object? current, IEnumerable<string>? includeProperties = null)
    {
        var description = ChangeLogBuilder.BuildDescription(previous, current, entity, includeProperties);
        await _activityLogService.CreateAsync(userId, "Create", entity, entityId, description);
    }

    public async Task UpdateAsync(int userId, string entity, int entityId, object? previous, object? current, IEnumerable<string>? includeProperties = null)
    {
        var description = ChangeLogBuilder.BuildDescription(previous, current, entity, includeProperties);
        await _activityLogService.CreateAsync(userId, "Update", entity, entityId, description);
    }

    public async Task DeleteAsync(int userId, string entity, int entityId, object? previous, object? current, IEnumerable<string>? includeProperties = null)
    {
        var description = ChangeLogBuilder.BuildDescription(previous, current, entity, includeProperties);
        await _activityLogService.CreateAsync(userId, "Delete", entity, entityId, description);
    }

    public async Task LogActionAsync(int userId, string action, string entity, int entityId, string description)
    {
        await _activityLogService.CreateAsync(userId, action, entity, entityId, description);
    }
}
