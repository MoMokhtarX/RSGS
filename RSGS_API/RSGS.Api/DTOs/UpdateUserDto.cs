using RSGS.Api.Enums;
using System.ComponentModel.DataAnnotations;

namespace RSGS.Api.DTOs;

public class UpdateUserDto
{
    [Required]
    public string FullName { get; set; } = string.Empty;

    [Required]
    [EmailAddress]
    [MaxLength(255)]
    public string Email { get; set; } = string.Empty;

    [Required]
    [EnumDataType(typeof(UserRole))]
    public UserRole Role { get; set; }

    public bool IsActive { get; set; }
}