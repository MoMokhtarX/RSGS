using RSGS.Api.DTOs;

namespace RSGS.Api.Interfaces;

public interface IDashboardService
{
    Task<DashboardDto> GetDashboardAsync();
}