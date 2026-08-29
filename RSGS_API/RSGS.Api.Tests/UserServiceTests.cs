using Microsoft.EntityFrameworkCore;
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

public sealed class UserServiceTests
{
    [Fact]
    public async Task UserLifecycle_EnforcesUniquenessAndPasswordConfirmation()
    {
        await using var db = Db();
        var service = Service(db, 1);
        var created = await service.CreateAsync(new CreateUserDto { Username = " user ", Password = "password-123", FullName = "User", Email = " user@test " , Role = UserRole.Sales});
        Assert.Equal("user", created.Username);
        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(new CreateUserDto { Username = "user", Password = "password-123", FullName = "Other", Email = "other@test", Role = UserRole.Sales }));
        await Assert.ThrowsAsync<BusinessException>(() => service.ChangePasswordAsync(created.Id, new ChangePasswordDto { CurrentPassword = "password-123", NewPassword = "new-password", ConfirmPassword = "different" }));
        Assert.True(await service.ChangePasswordAsync(created.Id, new ChangePasswordDto { CurrentPassword = "password-123", NewPassword = "new-password", ConfirmPassword = "new-password" }));
    }

    [Fact]
    public async Task UserCreation_RejectsInvalidRoleAndWeakPassword()
    {
        await using var db = Db();
        var service = Service(db, 1);

        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(new CreateUserDto
        {
            Username = "weak", Password = "short", FullName = "Weak", Email = "weak@test", Role = UserRole.Sales
        }));

        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(new CreateUserDto
        {
            Username = "badrole", Password = "valid-password", FullName = "Bad Role", Email = "badrole@test", Role = (UserRole)999
        }));
    }

    [Fact]
    public async Task UserLifecycle_ProtectsSelfAndLastActiveAdmin()
    {
        await using var db = Db();
        var passwords = new PasswordService();
        var admin = new User { Username = "admin", FullName = "Admin", Email = "a@test", PasswordHash = passwords.HashPassword("password-123"), Role = UserRole.Admin, IsActive = true };
        db.Users.Add(admin); await db.SaveChangesAsync();
        var service = Service(db, admin.Id);
        await Assert.ThrowsAsync<BusinessException>(() => service.SetActiveAsync(admin.Id, false));
        await Assert.ThrowsAsync<BusinessException>(() => service.DeleteAsync(admin.Id));
        await Assert.ThrowsAsync<BusinessException>(() => service.UpdateAsync(admin.Id, new UpdateUserDto { FullName = "Admin", Email = "a@test", Role = UserRole.Sales, IsActive = true }));
    }

    private static AppDbContext Db() => new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
    private static UserService Service(AppDbContext db, int current) => new(db, new PasswordService(), new Activity(), new Current(current));
    private sealed class Current(int id) : ICurrentUserService { public int UserId => id; public string Username => "admin"; public string Role => "Admin"; public bool IsAuthenticated => true; }
    private sealed class Activity : IActivityLogService { public Task<ActivityLog> CreateAsync(int a,string b,string c,int d,string e)=>Task.FromResult(new ActivityLog()); public Task<List<ActivityLog>> GetRecentAsync(int count=50)=>Task.FromResult(new List<ActivityLog>()); public Task<PagedResult<ActivityLogDto>> SearchAsync(ActivityLogQueryParameters p)=>Task.FromResult(new PagedResult<ActivityLogDto>()); }
}
