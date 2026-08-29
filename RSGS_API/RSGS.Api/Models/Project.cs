using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using RSGS.Api.Enums;

namespace RSGS.Api.Models;

[Table("projects")]
public class Project
{
    [Key]
    public int Id { get; set; }

    [Required]
    [MaxLength(50)]
    public string ProjectNumber { get; set; } = string.Empty;

    [Required]
    [MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    public int CustomerId { get; set; }

    public int? EngineerId { get; set; }

    public ProjectStatus Status { get; set; } = ProjectStatus.Draft;

    public DateTime CreatedDate { get; set; }

    public DateTime? InstallationDate { get; set; }

    [MaxLength(2000)]
    public string? Notes { get; set; }

    public decimal TotalValue { get; set; }

    public decimal TotalKw { get; set; }

    [MaxLength(500)]
    public string? Address { get; set; }

    [MaxLength(100)]
    public string? Governorate { get; set; }

    [MaxLength(100)]
    public string? City { get; set; }

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    [ForeignKey(nameof(CustomerId))]
    public Customer Customer { get; set; } = null!;

    [ForeignKey(nameof(EngineerId))]
    public User? Engineer { get; set; }

    // Navigation: project quotations
    public ICollection<Quotation>? Quotations { get; set; }
}