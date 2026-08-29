using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Services;

public class DashboardService : IDashboardService
{
    private readonly AppDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public DashboardService(
        AppDbContext context,
        ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<DashboardDto> GetDashboardAsync()
    {
        var dto = new DashboardDto();

        var customers = _context.Customers.AsNoTracking();
        var projects = _context.Projects.AsNoTracking();

        // Engineers see dashboard aggregates only for their assigned scope.
        // Other roles retain the existing company-wide dashboard.
        if (string.Equals(
                _currentUser.Role,
                UserRole.Engineer.ToString(),
                StringComparison.OrdinalIgnoreCase))
        {
            var engineerId = _currentUser.UserId;

            projects = projects.Where(x => x.EngineerId == engineerId);
            customers = customers.Where(x => x.AssignedUserId == engineerId);
        }

        dto.TotalCustomers = await customers.CountAsync();
        dto.TotalProjects = await projects.CountAsync();

        // User count is an administration metric and remains company-wide.
        dto.TotalUsers = await _context.Users.CountAsync();

        dto.ActiveProjects =
            await projects.CountAsync(
                x => x.Status == ProjectStatus.InProgress);

        dto.DraftProjects =
            await projects.CountAsync(
                x => x.Status == ProjectStatus.Draft);

        dto.FinishedProjects =
            await projects.CountAsync(
                x => x.Status == ProjectStatus.Completed);

        dto.TotalProjectsValue =
            await projects.SumAsync(x => (decimal?)x.TotalValue) ?? 0;

        dto.TotalKW =
            await projects.SumAsync(x => (decimal?)x.TotalKw) ?? 0;

        dto.RecentCustomers =
            await customers
                .OrderByDescending(x => x.CreatedAt)
                .Take(5)
                .Select(x => new RecentCustomerDto
                {
                    Id = x.Id,
                    Name = x.Name,
                    Phone = x.Phone,
                    CreatedAt = x.CreatedAt
                })
                .ToListAsync();

        dto.RecentProjects =
            await projects
                .OrderByDescending(x => x.CreatedDate)
                .Take(5)
                .Select(x => new RecentProjectDto
                {
                    Id = x.Id,
                    ProjectNumber = x.ProjectNumber,
                    Name = x.Name,
                    ProjectStatus = x.Status,
                    TotalValue = x.TotalValue,
                    CreatedDate = x.CreatedDate
                })
                .ToListAsync();

        dto.ProjectsByStatus = await projects
    .GroupBy(x => x.Status)
    .Select(x => new DashboardChartDto
    {
        Label = x.Key.ToString(),
        Value = x.Count()
    })
    .ToListAsync();

        dto.ProjectsByEngineer = await projects
            .Include(x => x.Engineer)
            .Where(x => x.Engineer != null)
            .GroupBy(x => x.Engineer!.FullName)
            .Select(x => new DashboardChartDto
            {
                Label = x.Key,
                Value = x.Count()
            })
            .ToListAsync();

        dto.CustomersByGovernorate = await customers
            .GroupBy(x => x.Governorate)
            .Select(x => new DashboardChartDto
            {
                Label = x.Key ?? "Unknown",
                Value = x.Count()
            })
            .ToListAsync();

        return dto;
    }
}