using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.DTOs;
using RSGS.Api.Interfaces;
using System.Security.Cryptography;
using System.Text;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : BaseApiController
{
    private readonly IAuthService _authService;
    private readonly ICurrentUserService _currentUser;
    private readonly IConfiguration _configuration;

    public AuthController(
        IAuthService authService,
        ICurrentUserService currentUser,
        IConfiguration configuration)
    {
        _authService = authService;
        _currentUser = currentUser;
        _configuration = configuration;
    }

    [HttpGet]
    [AllowAnonymous]
    public IActionResult Test() => Success(message: "Auth API Working");

    [HttpPost("register-admin")]
    [AllowAnonymous]
    public async Task<IActionResult> RegisterAdmin()
    {
        var configuredKey = _configuration["Admin:BootstrapKey"];
        var suppliedKey = Request.Headers["X-Admin-Bootstrap-Key"].ToString();

        if (string.IsNullOrWhiteSpace(configuredKey))
            return Problem(
                statusCode: StatusCodes.Status503ServiceUnavailable,
                title: "Admin bootstrap is not configured.");

        if (configuredKey.Length < 32)
            return Problem(
                statusCode: StatusCodes.Status503ServiceUnavailable,
                title: "Admin bootstrap key is too weak.");

        if (!FixedTimeEquals(configuredKey, suppliedKey))
            return Unauthorized(new { message = "Invalid admin bootstrap key." });

        var created = await _authService.RegisterAdminAsync();

        if (!created)
            return Conflict(new { message = "An Admin account already exists." });

        return Success(message: "Admin account created successfully.");
    }

    private static bool FixedTimeEquals(string expected, string actual)
    {
        var expectedBytes = Encoding.UTF8.GetBytes(expected);
        var actualBytes = Encoding.UTF8.GetBytes(actual);

        return expectedBytes.Length == actualBytes.Length &&
               CryptographicOperations.FixedTimeEquals(expectedBytes, actualBytes);
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login(LoginRequest request)
    {
        var result = await _authService.LoginAsync(request);

        if (!result.Success)
            return Unauthorized(result);

        return Success(result);
    }

    [HttpGet("me")]
    [Authorize]
    public IActionResult Me()
    {
        return Success(new
        {
            id = _currentUser.UserId,
            username = _currentUser.Username,
            role = _currentUser.Role,
            isAuthenticated = _currentUser.IsAuthenticated
        });
    }
}
