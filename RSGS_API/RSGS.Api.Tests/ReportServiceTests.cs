using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.Services;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class ReportServiceTests
{
    [Fact]
    public async Task EmptyDatabase_ReturnsZeroedSummary()
    {
        await using var db = Db();
        var summary = await new ReportService(db).GetSummaryAsync(new DateTime(2026, 1, 1), new DateTime(2026, 12, 31));
        Assert.Equal(0, summary.TotalCustomers);
        Assert.Equal(0, summary.InvoicedAmount);
        Assert.Empty(summary.RevenueByMonth);
    }

    [Fact]
    public async Task InvertedDateRange_IsRejected()
    {
        await using var db = Db();
        await Assert.ThrowsAsync<ArgumentException>(() => new ReportService(db).GetSummaryAsync(DateTime.UtcNow, DateTime.UtcNow.AddDays(-1)));
    }

    private static AppDbContext Db() => new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
}
