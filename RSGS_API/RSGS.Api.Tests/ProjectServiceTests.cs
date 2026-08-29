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

public sealed class ProjectServiceTests
{
    [Fact]
    public async Task ProjectLifecycle_ValidatesDependenciesAndProtectsCompletedProjects()
    {
        await using var db = Db();
        var customer = new Customer { Name = "Customer", Phone = "1" };
        var engineer = new User { Username = "eng", FullName = "Engineer", Email = "e@test", Role = UserRole.Engineer, IsActive = true };
        db.AddRange(customer, engineer); await db.SaveChangesAsync();
        var service = Service(db, "Admin");
        var created = await service.CreateAsync(new CreateProjectDto { ProjectNumber = "P-1", Name = "Solar", CustomerId = customer.Id, EngineerId = engineer.Id, Status = ProjectStatus.Draft });
        Assert.Equal("P-1", created.ProjectNumber);
        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(new CreateProjectDto { ProjectNumber = "P-1", Name = "Duplicate", CustomerId = customer.Id }));
        Assert.True(await service.ChangeStatusAsync(created.Id, ProjectStatus.Completed));
        await Assert.ThrowsAsync<BusinessException>(() => service.DeleteAsync(created.Id));
        await Assert.ThrowsAsync<BusinessException>(() => service.AssignEngineerAsync(created.Id, engineer.Id));
    }

    [Fact]
    public async Task Engineer_CanOnlyReadAndChangeOwnProject()
    {
        await using var db = Db();
        var customer = new Customer { Name = "Customer", Phone = "1" };
        var owner = new User { Username = "owner", FullName = "Owner", Email = "o@test", Role = UserRole.Engineer, IsActive = true };
        var other = new User { Username = "other", FullName = "Other", Email = "x@test", Role = UserRole.Engineer, IsActive = true };
        db.AddRange(customer, owner, other); await db.SaveChangesAsync();
        var project = new Project { ProjectNumber = "P-2", Name = "Solar", CustomerId = customer.Id, EngineerId = owner.Id, Customer = customer };
        db.Projects.Add(project); await db.SaveChangesAsync();
        var service = Service(db, "Engineer", other.Id);
        Assert.Empty(await service.GetAllAsync());
        await Assert.ThrowsAsync<BusinessException>(() => service.GetByIdAsync(project.Id));
        await Assert.ThrowsAsync<BusinessException>(() => service.ChangeStatusAsync(project.Id, ProjectStatus.InProgress));
        await Assert.ThrowsAsync<BusinessException>(() => service.DeleteAsync(project.Id));
    }

    private static AppDbContext Db() => new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
    private static ProjectService Service(AppDbContext db, string role, int id = 1) => new(new ProjectRepository(db), new Activity(), new UserContext(id, role), new AuditService(new Activity()), db);
    private sealed class UserContext(int id, string role) : ICurrentUserService { public int UserId => id; public string Username => "test"; public string Role => role; public bool IsAuthenticated => true; }
    private sealed class Activity : IActivityLogService
    {
        public Task<ActivityLog> CreateAsync(int userId, string action, string entity, int entityId, string description) => Task.FromResult(new ActivityLog());
        public Task<List<ActivityLog>> GetRecentAsync(int count = 50) => Task.FromResult(new List<ActivityLog>());
        public Task<PagedResult<ActivityLogDto>> SearchAsync(ActivityLogQueryParameters parameters) => Task.FromResult(new PagedResult<ActivityLogDto>());
    }
}
