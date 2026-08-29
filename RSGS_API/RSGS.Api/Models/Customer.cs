using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RSGS.Api.Models;

[Table("customers")]
public class Customer
{
    [Key]
    public int Id { get; set; }

    [Required]
    [MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [MaxLength(30)]
    public string Phone { get; set; } = string.Empty;

    [MaxLength(30)]
    public string? Phone2 { get; set; }

    [MaxLength(255)]
    public string? Email { get; set; }

    [MaxLength(2000)]
    public string? Notes { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    [MaxLength(100)]
    public string? Governorate { get; set; }

    [MaxLength(100)]
    public string? City { get; set; }

    [MaxLength(100)]
    public string? Channel { get; set; }

    public DateTime? InquiryDate { get; set; }

    [MaxLength(100)]
    public string? FollowUpStatus { get; set; }

    public int? AssignedUserId { get; set; }

    [MaxLength(2000)]
    public string? FirstCallNotes { get; set; }

    public DateTime? FirstActionDate { get; set; }

    [MaxLength(2000)]
    public string? SecondCallNotes { get; set; }

    public DateTime? SecondActionDate { get; set; }

    [MaxLength(2000)]
    public string? ThirdCallNotes { get; set; }

    public DateTime? ThirdActionDate { get; set; }

    [MaxLength(2000)]
    public string? FourthCallNotes { get; set; }

    public DateTime? FourthActionDate { get; set; }

    [ForeignKey(nameof(AssignedUserId))]
    public User? AssignedUser { get; set; }

    public ICollection<Project>? Projects { get; set; }

    // Navigation: customer's quotations
    public ICollection<Quotation>? Quotations { get; set; }
}