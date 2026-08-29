using System.ComponentModel.DataAnnotations;

namespace RSGS.Api.DTOs;

public class ResetPasswordDto
{
    [Required]
    [MinLength(12)]
    public string NewPassword { get; set; } = string.Empty;
}
