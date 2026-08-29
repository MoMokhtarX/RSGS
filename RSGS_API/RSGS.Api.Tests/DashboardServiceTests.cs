using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.Enums;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Services;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class DashboardServiceTests
{
    [Fact]
    public async Task EngineerDashboard_IsScopedToAssignedCustomersAndProjects()
    {
        await using var db = Db();
        var engineer = new User { Username = "eng", FullName = "Engineer", Email = "e@test", Role = UserRole.Engineer, IsActive = true };
        var other = new User { Username = "other", FullName = "Other", Email = "o@test", Role = UserRole.Engineer, IsActive = true };
        var mine = new Customer { Name = "Mine", Phone = "1", AssignedUser = engineer };
        var theirs = new Customer { Name = "Theirs", Phone = "2", AssignedUser = other };
        db.AddRange(engineer, other, mine, theirs); await db.SaveChangesAsync();
        db.Projects.AddRange(
            new Project { ProjectNumber = "M", Name = "Mine", CustomerId = mine.Id, EngineerId = engineer.Id, Status = ProjectStatus.InProgress, TotalValue = 10, TotalKw = 2 },
            new Project { ProjectNumber = "T", Name = "Theirs", CustomerId = theirs.Id, EngineerId = other.Id, Status = ProjectStatus.Completed, TotalValue = 99, TotalKw = 9 });
        await db.SaveChangesAsync();

        var dashboard = await new DashboardService(db, new Current(engineer.Id, "Engineer")).GetDashboardAsync();
        Assert.Equal(1, dashboard.TotalCustomers);
        Assert.Equal(1, dashboard.TotalProjects);
        Assert.Equal(10, dashboard.TotalProjectsValue);
        Assert.Equal(2, dashboard.TotalKW);
        Assert.Equal(2, dashboard.TotalUsers);
    }

    [Fact]
    public async Task EmptyDashboard_ReturnsSafeZeroTotals()
    {
        await using var db = Db();
        var dashboard = await new DashboardService(db, new Current(1, "Admin")).GetDashboardAsync();
        Assert.Equal(0, dashboard.TotalCustomers);
        Assert.Empty(dashboard.RecentProjects);
    }

    private static AppDbContext Db() => new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
    private sealed class Current(int id, string role) : ICurrentUserService { public int UserId => id; public string Role => role; public string Username => "test"; public bool IsAuthenticated => true; }
}
