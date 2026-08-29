using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using RSGS.Api.Common;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.DTOs.ActivityLogs;
using RSGS.Api.Enums;
using RSGS.Api.Exceptions;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Services;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class AuthServiceTests
{
    [Fact]
    public async Task RegistrationAndLogin_CreateOneAdminAndIssueToken()
    {
        await using var db = Db();
        var service = Service(db);
        Assert.True(await service.RegisterAdminAsync());
        Assert.False(await service.RegisterAdminAsync());
        var login = await service.LoginAsync(new LoginRequest { Username = "admin", Password = "very-secure-password" });
        Assert.True(login.Success);
        Assert.False(string.IsNullOrWhiteSpace(login.Token));
        Assert.False((await service.LoginAsync(new LoginRequest { Username = "admin", Password = "wrong" })).Success);
    }

    [Fact]
    public async Task RegistrationRequiresCompleteConfigurationAndDisabledUsersCannotLogin()
    {
        await using var db = Db();
        var incomplete = new AuthService(db, new JwtService(Config()), new PasswordService(), new Activity(), new ConfigurationBuilder().Build());
        await Assert.ThrowsAsync<BusinessException>(() => incomplete.RegisterAdminAsync());
        var password = new PasswordService();
        db.Users.Add(new User { Username = "disabled", PasswordHash = password.HashPassword("valid-password"), FullName = "Disabled", Email = "d@test", Role = UserRole.Sales, IsActive = false });
        await db.SaveChangesAsync();
        Assert.False((await Service(db).LoginAsync(new LoginRequest { Username = "disabled", Password = "valid-password" })).Success);
    }

    private static AppDbContext Db() => new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
    private static AuthService Service(AppDbContext db) => new(db, new JwtService(Config()), new PasswordService(), new Activity(), Config(includeAdmin: true));
    private static IConfiguration Config(bool includeAdmin = false)
    {
        var values = new Dictionary<string, string?> { ["Jwt:Key"] = new string('k', 32), ["Jwt:Issuer"] = "issuer", ["Jwt:Audience"] = "audience" };
        if (includeAdmin) { values["Admin:Username"] = "admin"; values["Admin:Password"] = "very-secure-password"; values["Admin:FullName"] = "Admin"; values["Admin:Email"] = "admin@test"; }
        return new ConfigurationBuilder().AddInMemoryCollection(values).Build();
    }
    private sealed class Activity : IActivityLogService { public Task<ActivityLog> CreateAsync(int a,string b,string c,int d,string e)=>Task.FromResult(new ActivityLog()); public Task<List<ActivityLog>> GetRecentAsync(int count=50)=>Task.FromResult(new List<ActivityLog>()); public Task<PagedResult<ActivityLogDto>> SearchAsync(ActivityLogQueryParameters p)=>Task.FromResult(new PagedResult<ActivityLogDto>()); }
}
