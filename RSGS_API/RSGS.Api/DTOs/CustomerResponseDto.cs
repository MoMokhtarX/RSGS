namespace RSGS.Api.DTOs;

public class CustomerResponseDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? Phone2 { get; set; }
    public string? Email { get; set; }
    public string? Notes { get; set; }
    public string? Governorate { get; set; }
    public string? City { get; set; }
    public string? Channel { get; set; }
    public DateTime? InquiryDate { get; set; }
    public string? FollowUpStatus { get; set; }
    public int? AssignedUserId { get; set; }

    public string? FirstCallNotes { get; set; }
    public DateTime? FirstActionDate { get; set; }
    public string? SecondCallNotes { get; set; }
    public DateTime? SecondActionDate { get; set; }
    public string? ThirdCallNotes { get; set; }
    public DateTime? ThirdActionDate { get; set; }
    public string? FourthCallNotes { get; set; }
    public DateTime? FourthActionDate { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public AssignedUserDto? AssignedUser { get; set; }
}

public class AssignedUserDto
{
    public int Id { get; set; }
    public string FullName { get; set; } = string.Empty;
}
