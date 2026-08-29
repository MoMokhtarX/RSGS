using Microsoft.EntityFrameworkCore;
using RSGS.Api.Common;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.DTOs.ActivityLogs;
using RSGS.Api.Enums;
using RSGS.Api.Exceptions;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Repositories;
using RSGS.Api.Services;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class CustomerServiceTests
{
    [Fact]
    public async Task Create_AssignsOnlyActiveEngineersAndNormalizesUtcDates()
    {
        await using var db = Db();
        var engineer = new User { Username = "eng", FullName = "Engineer", Email = "e@test", Role = UserRole.Engineer, IsActive = true };
        db.Users.Add(engineer); await db.SaveChangesAsync();
        var service = Service(db, "Admin");
        var result = await service.CreateAsync(new CustomerDto { Name = "Customer", Phone = "+2012345", AssignedUserId = engineer.Id, InquiryDate = new DateTime(2026, 1, 1) });

        Assert.Equal(engineer.Id, result.AssignedUserId);
        Assert.Equal(DateTimeKind.Utc, result.InquiryDate!.Value.Kind);
    }

    [Fact]
    public async Task Create_RejectsInvalidAssigneeAndEngineerManagement()
    {
        await using var db = Db();
        db.Users.Add(new User { Username = "sales", FullName = "Sales", Email = "s@test", Role = UserRole.Sales, IsActive = true });
        await db.SaveChangesAsync();
        var dto = new CustomerDto { Name = "Customer", Phone = "+2012345", AssignedUserId = 1 };
        await Assert.ThrowsAsync<BusinessException>(() => Service(db, "Admin").CreateAsync(dto));
        await Assert.ThrowsAsync<BusinessException>(() => Service(db, "Engineer").CreateAsync(new CustomerDto { Name = "Customer", Phone = "+2012345" }));
    }

    [Fact]
    public async Task EngineerScope_OnlyReturnsAssignedCustomers()
    {
        await using var db = Db();
        var engineer = new User { Username = "eng", FullName = "Engineer", Email = "e@test", Role = UserRole.Engineer, IsActive = true };
        db.Users.Add(engineer); await db.SaveChangesAsync();
        db.Customers.AddRange(new Customer { Name = "Mine", Phone = "1", AssignedUserId = engineer.Id }, new Customer { Name = "Other", Phone = "2" });
        await db.SaveChangesAsync();

        var customers = await Service(db, "Engineer", engineer.Id).GetAllAsync();
        Assert.Single(customers);
        Assert.Equal("Mine", customers[0].Name);
    }

    private static AppDbContext Db() => new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
    private static CustomerService Service(AppDbContext db, string role, int id = 1) => new(new CustomerRepository(db), new Activity(), new UserContext(id, role), db, new AuditService(new Activity()));
    private sealed class UserContext(int id, string role) : ICurrentUserService { public int UserId => id; public string Username => "test"; public string Role => role; public bool IsAuthenticated => true; }
    private sealed class Activity : IActivityLogService
    {
        public Task<ActivityLog> CreateAsync(int userId, string action, string entity, int entityId, string description) => Task.FromResult(new ActivityLog());
        public Task<List<ActivityLog>> GetRecentAsync(int count = 50) => Task.FromResult(new List<ActivityLog>());
        public Task<PagedResult<ActivityLogDto>> SearchAsync(ActivityLogQueryParameters parameters) => Task.FromResult(new PagedResult<ActivityLogDto>());
    }
}
