using System.ComponentModel.DataAnnotations;

namespace RSGS.Api.DTOs;

public class CustomerDto
{
    [Required]
    [MinLength(2)]
    [MaxLength(200)]
    public string Name { get; set; } = "";

    [Required]
    [Phone]
    [MaxLength(30)]
    public string Phone { get; set; } = "";

    [Phone]
    [MaxLength(30)]
    public string? Phone2 { get; set; }

    [EmailAddress]
    [MaxLength(200)]
    public string? Email { get; set; }

    [MaxLength(2000)]
    public string? Notes { get; set; }

    [MaxLength(100)]
    public string? Governorate { get; set; }

    [MaxLength(100)]
    public string? City { get; set; }

    [MaxLength(100)]
    public string? Channel { get; set; }

    public DateTime? InquiryDate { get; set; }

    [MaxLength(100)]
    public string? FollowUpStatus { get; set; }

    [Range(1, int.MaxValue)]
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
}