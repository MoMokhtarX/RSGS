using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.Models;
using RSGS.Api.Repositories;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class GenericRepositoryTests
{
    [Fact]
    public async Task GenericRepository_PerformsCrudAndPredicateQueries()
    {
        await using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var repository = new GenericRepository<Customer>(db);
        var customer = await repository.AddAsync(new Customer { Name = "First", Phone = "1" });

        Assert.True(await repository.ExistsAsync(x => x.Name == "First"));
        Assert.Equal(customer.Id, (await repository.GetByIdAsync(customer.Id))!.Id);
        customer.Name = "Updated";
        await repository.UpdateAsync(customer);
        Assert.Single(await repository.Query().Where(x => x.Name == "Updated").ToListAsync());
        await repository.DeleteAsync(customer);
        Assert.Empty(await repository.GetAllAsync());
    }
}
