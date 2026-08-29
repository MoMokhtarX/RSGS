using RSGS.Api.Enums;

namespace RSGS.Api.DTOs;

public class ProjectListItemDto
{
    public int Id { get; set; }
    public string ProjectNumber { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public int CustomerId { get; set; }
    public string? CustomerName { get; set; }
    public string? CustomerChannel { get; set; }
    public int? EngineerId { get; set; }
    public string? EngineerName { get; set; }
    public ProjectStatus Status { get; set; }
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
