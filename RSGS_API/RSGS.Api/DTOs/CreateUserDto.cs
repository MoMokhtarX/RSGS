using RSGS.Api.Enums;
using System.ComponentModel.DataAnnotations;

namespace RSGS.Api.DTOs;

public class CreateUserDto
{
    [Required]
    public string Username { get; set; } = string.Empty;

    [Required]
    [MinLength(12)]
    public string Password { get; set; } = string.Empty;

    [Required]
    public string FullName { get; set; } = string.Empty;

    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    [EnumDataType(typeof(UserRole))]
    public UserRole Role { get; set; }
}