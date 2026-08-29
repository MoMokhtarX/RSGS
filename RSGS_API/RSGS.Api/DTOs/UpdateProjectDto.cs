using RSGS.Api.Enums;
using System.ComponentModel.DataAnnotations;

namespace RSGS.Api.DTOs;

public class UpdateProjectDto
{
    [Required]
    [MaxLength(50)]
    public string ProjectNumber { get; set; } = string.Empty;

    [Required]
    [MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    [Range(1, int.MaxValue)]
    public int CustomerId { get; set; }

    public int? EngineerId { get; set; }

    [Required]
    [EnumDataType(typeof(ProjectStatus))]
    public ProjectStatus Status { get; set; } = ProjectStatus.Draft;

    public DateTime? InstallationDate { get; set; }

    [MaxLength(1000)]
    public string? Notes { get; set; }

    [Range(0, 100000000)]
    public decimal TotalValue { get; set; }

    [Range(0, 100000)]
    public decimal TotalKW { get; set; }

    [MaxLength(500)]
    public string? Address { get; set; }

    [MaxLength(100)]
    public string? Governorate { get; set; }

    [MaxLength(100)]
    public string? City { get; set; }

    [Range(-90, 90)]
    public double? Latitude { get; set; }

    [Range(-180, 180)]
    public double? Longitude { get; set; }
}