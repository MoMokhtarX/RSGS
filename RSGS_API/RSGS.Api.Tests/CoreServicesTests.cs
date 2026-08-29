using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using RSGS.Api.Controllers;
using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Services;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class CoreServicesTests
{
    [Fact]
    public void PasswordService_HashesAndVerifiesPassword()
    {
        var service = new PasswordService();

        var hash = service.HashPassword("a-secure-password");

        Assert.NotEqual("a-secure-password", hash);
        Assert.True(service.VerifyPassword("a-secure-password", hash));
        Assert.False(service.VerifyPassword("wrong-password", hash));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void PasswordService_RejectsEmptyPasswords(string? password)
    {
        var service = new PasswordService();

        Assert.Throws<ArgumentException>(() => service.HashPassword(password!));
        Assert.False(service.VerifyPassword(password!, "hash"));
    }

    [Fact]
    public void PasswordService_RejectsPasswordsShorterThanMinimum()
    {
        var service = new PasswordService();

        Assert.Throws<ArgumentException>(() => service.HashPassword("12345678901"));
        var hash = service.HashPassword("123456789012");
        Assert.True(service.VerifyPassword("123456789012", hash));
    }

    [Fact]
    public void JwtService_GeneratesTokenWithExpectedIdentityClaims()
    {
        var service = new JwtService(Configuration());
        var user = new User { Id = 42, Username = "sam", FullName = "Sam Solar", Role = UserRole.Manager };

        var token = service.GenerateToken(user);
        var parsed = new JwtSecurityTokenHandler().ReadJwtToken(token);

        Assert.Equal("issuer", parsed.Issuer);
        Assert.Equal("audience", parsed.Audiences.Single());
        Assert.Equal("42", parsed.Claims.Single(c => c.Type == ClaimTypes.NameIdentifier).Value);
        Assert.Equal("sam", parsed.Claims.Single(c => c.Type == ClaimTypes.Name).Value);
        Assert.Equal("Manager", parsed.Claims.Single(c => c.Type == ClaimTypes.Role).Value);
    }

    [Theory]
    [InlineData("Jwt:Key", "")]
    [InlineData("Jwt:Key", "short")]
    [InlineData("Jwt:Issuer", "")]
    [InlineData("Jwt:Audience", "")]
    [InlineData("Jwt:ExpireHours", "0")]
    public void JwtService_RejectsInvalidConfiguration(string key, string value)
    {
        var values = new Dictionary<string, string?>
        {
            ["Jwt:Key"] = new string('k', 32),
            ["Jwt:Issuer"] = "issuer",
            ["Jwt:Audience"] = "audience",
            ["Jwt:ExpireHours"] = "1"
        };
        values[key] = value;

        var service = new JwtService(new ConfigurationBuilder().AddInMemoryCollection(values).Build());

        Assert.Throws<InvalidOperationException>(() => service.GenerateToken(new User()));
    }

    [Fact]
    public void CurrentUserService_ReadsAuthenticatedClaims()
    {
        var context = new DefaultHttpContext();
        context.User = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(ClaimTypes.NameIdentifier, "7"),
            new Claim(ClaimTypes.Name, "lina"),
            new Claim(ClaimTypes.Role, "Admin")
        ], "test"));
        var service = new CurrentUserService(new HttpContextAccessor { HttpContext = context });

        Assert.True(service.IsAuthenticated);
        Assert.Equal(7, service.UserId);
        Assert.Equal("lina", service.Username);
        Assert.Equal("Admin", service.Role);
    }

    [Fact]
    public void CurrentUserService_UsesSafeDefaultsWithoutClaims()
    {
        var service = new CurrentUserService(new HttpContextAccessor());

        Assert.False(service.IsAuthenticated);
        Assert.Equal(0, service.UserId);
        Assert.Empty(service.Username);
        Assert.Empty(service.Role);
    }

    [Fact]
    public async Task RegisterAdmin_RejectsRequestsWhenBootstrapIsNotConfigured()
    {
        var controller = BootstrapController(new Dictionary<string, string?>(), new FakeAuthService());

        var result = await controller.RegisterAdmin();

        var problem = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status503ServiceUnavailable, problem.StatusCode);
    }

    [Fact]
    public async Task RegisterAdmin_RejectsAnIncorrectBootstrapKey()
    {
        var controller = BootstrapController(new Dictionary<string, string?> { ["Admin:BootstrapKey"] = new string('e', 32) }, new FakeAuthService());
        controller.Request.Headers["X-Admin-Bootstrap-Key"] = "incorrect";

        var result = await controller.RegisterAdmin();

        Assert.IsType<UnauthorizedObjectResult>(result);
    }

    [Fact]
    public async Task RegisterAdmin_CreatesAdminWithMatchingBootstrapKey()
    {
        var auth = new FakeAuthService();
        var controller = BootstrapController(new Dictionary<string, string?> { ["Admin:BootstrapKey"] = new string('e', 32) }, auth);
        controller.Request.Headers["X-Admin-Bootstrap-Key"] = new string('e', 32);

        var result = await controller.RegisterAdmin();

        Assert.IsType<OkObjectResult>(result);
        Assert.Equal(1, auth.RegisterCalls);
    }

    private static AuthController BootstrapController(
        Dictionary<string, string?> values,
        IAuthService authService)
    {
        var controller = new AuthController(
            authService,
            new CurrentUserService(new HttpContextAccessor()),
            new ConfigurationBuilder().AddInMemoryCollection(values).Build())
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() }
        };

        return controller;
    }

    private static IConfiguration Configuration() => new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Jwt:Key"] = new string('k', 32),
            ["Jwt:Issuer"] = "issuer",
            ["Jwt:Audience"] = "audience",
            ["Jwt:ExpireHours"] = "2"
        })
        .Build();

    private sealed class FakeAuthService : IAuthService
    {
        public int RegisterCalls { get; private set; }

        public Task<bool> RegisterAdminAsync()
        {
            RegisterCalls++;
            return Task.FromResult(true);
        }

        public Task<LoginResponse> LoginAsync(LoginRequest request) =>
            Task.FromResult(new LoginResponse());
    }
}
