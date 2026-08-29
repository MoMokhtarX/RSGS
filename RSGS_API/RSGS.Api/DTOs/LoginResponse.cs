namespace RSGS.Api.DTOs;

public class LoginResponse
{
    public bool Success { get; set; }

    public string Message { get; set; } = "";

    public string? Token { get; set; }

    // Required by the Flutter AuthUser contract.
    public int? Id { get; set; }

    public string? Username { get; set; }

    public string? Email { get; set; }

    public string? FullName { get; set; }

    public string? Role { get; set; }
}