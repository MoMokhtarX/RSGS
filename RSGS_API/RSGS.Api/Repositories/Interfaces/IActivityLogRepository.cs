using RSGS.Api.Common;
using RSGS.Api.DTOs;
using RSGS.Api.DTOs.ActivityLogs;
using RSGS.Api.Models;

namespace RSGS.Api.Repositories.Interfaces;

public interface IActivityLogRepository : IGenericRepository<ActivityLog>
{
    Task<List<ActivityLog>> GetRecentAsync(int count = 50);

    Task<PagedResult<ActivityLogDto>> SearchAsync(
        ActivityLogQueryParameters parameters);
}