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

public sealed class CatalogAndInventoryServiceTests
{
    [Fact]
    public async Task ProductCatalog_EnforcesPricingAndCodeUniqueness()
    {
        await using var db = CreateDb();
        var service = new ProductComponentService(db, new ActivitySpy(), new CurrentUser(), new AuditService(new ActivitySpy()));
        var dto = Product(" panel-1 ");

        var created = await service.CreateAsync(dto);
        Assert.Equal("panel-1", created.Code);
        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(Product("PANEL-1")));
        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(Product("P-2", cost: 20, price: 19)));
    }

    [Fact]
    public async Task ProductCatalog_FiltersAndUpdatesProducts()
    {
        await using var db = CreateDb();
        var service = new ProductComponentService(db, new ActivitySpy(), new CurrentUser(), new AuditService(new ActivitySpy()));
        var active = await service.CreateAsync(Product("A-1", name: "Alpha Panel"));
        await service.CreateAsync(Product("B-1", name: "Beta Panel"));

        var found = await service.GetAllAsync("alpha", active.Category, activeOnly: true);
        Assert.Single(found);
        var update = new UpdateProductComponentDto { Name = "Updated", Category = active.Category, Unit = "pcs", CostPrice = 10, SellingPrice = 12, IsActive = false };
        var changed = await service.UpdateAsync(active.Id, update);
        Assert.False(changed!.IsActive);
        Assert.False(await service.SetActiveAsync(999, true));
    }

    [Fact]
    public async Task Inventory_AdjustmentPreventsNegativeStockAndFlagsLowStock()
    {
        await using var db = CreateDb();
        var product = new ProductComponent { Code = "INV", Name = "Inventory", Category = QuotationItemCategory.SolarPanels, Unit = "pcs", IsActive = true };
        db.ProductComponents.Add(product);
        await db.SaveChangesAsync();
        var service = new InventoryService(db, new CurrentUser(), new ActivitySpy());

        var initial = await service.AdjustAsync(new InventoryAdjustmentDto { ProductComponentId = product.Id, Quantity = 5, Increase = true });
        Assert.Equal(5, initial!.QuantityOnHand);
        await Assert.ThrowsAsync<BusinessException>(() => service.AdjustAsync(new InventoryAdjustmentDto { ProductComponentId = product.Id, Quantity = 6, Increase = false }));
        var reorder = await service.SetReorderLevelAsync(product.Id, new SetReorderLevelDto { ReorderLevel = 5 });
        Assert.True(reorder!.IsLowStock);
        Assert.Single(await service.GetAllAsync(lowStockOnly: true));
        Assert.Null(await service.AdjustAsync(new InventoryAdjustmentDto { ProductComponentId = 999, Quantity = 1, Increase = true }));
    }

    private static AppDbContext CreateDb() => new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
    private static CreateProductComponentDto Product(string code, string name = "Panel", decimal cost = 10, decimal price = 11) => new()
    {
        Code = code, Name = name, Category = QuotationItemCategory.SolarPanels, Unit = "pcs", CostPrice = cost, SellingPrice = price
    };

    private sealed class CurrentUser : ICurrentUserService { public int UserId => 1; public string Username => "test"; public string Role => "Admin"; public bool IsAuthenticated => true; }
    private sealed class ActivitySpy : IActivityLogService
    {
        public Task<ActivityLog> CreateAsync(int userId, string action, string entity, int entityId, string description) => Task.FromResult(new ActivityLog());
        public Task<List<ActivityLog>> GetRecentAsync(int count = 50) => Task.FromResult(new List<ActivityLog>());
        public Task<PagedResult<ActivityLogDto>> SearchAsync(ActivityLogQueryParameters parameters) => Task.FromResult(new PagedResult<ActivityLogDto>());
    }
}
