using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.Enums;
using RSGS.Api.Models;
using RSGS.Api.Services;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class GlobalSearchServiceTests
{
    [Fact]
    public async Task Search_ReturnsCustomerProjectAndQuotationMatches()
    {
        await using var db = Db();
        var customer = new Customer { Name = "Solar Client", Phone = "123" };
        db.Customers.Add(customer); await db.SaveChangesAsync();
        db.Projects.Add(new Project { ProjectNumber = "SOL-1", Name = "Solar Project", CustomerId = customer.Id });
        db.Quotations.Add(new Quotation { QuotationNumber = "SOL-Q", CustomerId = customer.Id, Type = QuotationType.OnGrid, Status = QuotationStatus.Draft });
        await db.SaveChangesAsync();
        var results = await new GlobalSearchService(db).SearchAsync("sol", null);
        Assert.Equal(3, results.Count);
        Assert.Contains(results, x => x.Type == "Customer");
        Assert.Contains(results, x => x.Type == "Project");
        Assert.Contains(results, x => x.Type == "Quotation");
        Assert.Empty(await new GlobalSearchService(db).SearchAsync("x", null));
    }

    [Fact]
    public async Task Search_RespectsEngineerScope()
    {
        await using var db = Db();
        var engineer = new User { Username = "eng", FullName = "Engineer", Email = "e@test", Role = UserRole.Engineer, IsActive = true };
        var customer = new Customer { Name = "Scoped Solar", Phone = "1", AssignedUser = engineer };
        db.AddRange(engineer, customer); await db.SaveChangesAsync();
        db.Projects.Add(new Project { ProjectNumber = "S-1", Name = "Scoped Solar", CustomerId = customer.Id, EngineerId = engineer.Id });
        await db.SaveChangesAsync();
        Assert.Equal(2, (await new GlobalSearchService(db).SearchAsync("solar", engineer.Id)).Count);
        Assert.Empty(await new GlobalSearchService(db).SearchAsync("solar", engineer.Id + 99));
    }

    private static AppDbContext Db() => new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
}
