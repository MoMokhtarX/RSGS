namespace RSGS.Api.DTOs;

public class ProjectResponseDto
{
    public int Id { get; set; }

    public string ProjectNumber { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public int CustomerId { get; set; }

    public string? CustomerName { get; set; }

    public string? CustomerChannel { get; set; }

    public int? EngineerId { get; set; }

    public string? EngineerName { get; set; }

    // Kept as the UI-friendly values used by the Flutter application:
    // Draft, Pending, Approved, In Progress, Completed, Cancelled.
    public string Status { get; set; } = "Draft";

    public DateTime CreatedDate { get; set; }

    public DateTime? InstallationDate { get; set; }

    public string? Notes { get; set; }

    public decimal TotalValue { get; set; }

    public decimal TotalKW { get; set; }

    public string? Address { get; set; }

    public string? Governorate { get; set; }

    public string? City { get; set; }

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }
}

public class ProjectStatisticsDto
{
    public int Total { get; set; }

    public int Draft { get; set; }

    public int Pending { get; set; }

    public int Approved { get; set; }

    public int InProgress { get; set; }

    public int Completed { get; set; }

    public int Cancelled { get; set; }

    public decimal TotalValue { get; set; }

    public decimal TotalKW { get; set; }
}
