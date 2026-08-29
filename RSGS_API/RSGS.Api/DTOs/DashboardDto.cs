namespace RSGS.Api.DTOs;

public class DashboardDto
{
    public int TotalCustomers { get; set; }

    public int TotalProjects { get; set; }

    public int TotalUsers { get; set; }

    public int ActiveProjects { get; set; }

    public int DraftProjects { get; set; }

    public int FinishedProjects { get; set; }

    public decimal TotalProjectsValue { get; set; }

    public decimal TotalKW { get; set; }

    public List<RecentCustomerDto> RecentCustomers { get; set; } = new();

    public List<RecentProjectDto> RecentProjects { get; set; } = new();

    public List<DashboardChartDto> ProjectsByStatus { get; set; } = new();

    public List<DashboardChartDto> ProjectsByEngineer { get; set; } = new();

    public List<DashboardChartDto> CustomersByGovernorate { get; set; } = new();

}