using RSGS.Api.Common;
using RSGS.Api.DTOs.ActivityLogs;
using RSGS.Api.Models;

namespace RSGS.Api.Interfaces;

public interface IActivityLogService
{
    Task<ActivityLog> CreateAsync(
        int userId,
        string action,
        string entity,
        int entityId,
        string description);

    Task<List<ActivityLog>> GetRecentAsync(int count = 50);

    Task<PagedResult<ActivityLogDto>> SearchAsync(
        ActivityLogQueryParameters parameters);
}