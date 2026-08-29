using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Interfaces;
using RSGS.Api.Utilities;

namespace RSGS.Api.Services;

public sealed class ReportService : IReportService
{
    private readonly AppDbContext _context;
    public ReportService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<ReportSummaryDto> GetSummaryAsync(DateTime? from, DateTime? to)
    {
        var end = DateTimeUtility.ToUtc(to ?? DateTime.UtcNow);
        var start = DateTimeUtility.ToUtc(from ?? end.AddMonths(-11));

        if (start > end)
            throw new ArgumentException("The report start date must be before the end date.");

        var customers = _context.Customers.AsNoTracking();
        var projects = _context.Projects.AsNoTracking();
        var quotations = _context.Quotations.AsNoTracking();
        var invoices = _context.Invoices.AsNoTracking();
        var payments = _context.Payments.AsNoTracking();
        var purchaseOrders = _context.PurchaseOrders.AsNoTracking();

        var rangeProjects = projects.Where(x => x.CreatedDate >= start && x.CreatedDate <= end);
        var rangeQuotations = quotations.Where(x => x.QuotationDate >= start && x.QuotationDate <= end);
        var rangeInvoices = invoices.Where(x => x.IssueDate >= start && x.IssueDate <= end);
        var rangePayments = payments.Where(x => x.PaymentDate >= start && x.PaymentDate <= end);
        var rangePurchaseOrders = purchaseOrders.Where(x => x.OrderDate >= start && x.OrderDate <= end);

        var totalCustomers = await customers.CountAsync();
        var totalProjects = await rangeProjects.CountAsync();
        var activeProjects = await rangeProjects.CountAsync(x => x.Status == ProjectStatus.InProgress);
        var completedProjects = await rangeProjects.CountAsync(x => x.Status == ProjectStatus.Completed);
        var totalQuotations = await rangeQuotations.CountAsync();
        var approvedQuotations = await rangeQuotations.CountAsync(x => x.Status == QuotationStatus.Approved);

        var quotationValue = await rangeQuotations
            .Where(x => x.Status != QuotationStatus.Rejected && x.Status != QuotationStatus.Expired)
            .SumAsync(x => (decimal?)x.TotalPrice) ?? 0m;

        var invoicedAmount = await rangeInvoices
            .Where(x => x.Status != InvoiceStatus.Cancelled)
            .SumAsync(x => (decimal?)x.Total) ?? 0m;

        var collectedAmount = await rangePayments.SumAsync(x => (decimal?)x.Amount) ?? 0m;
        var outstandingAmount = Math.Max(0m, invoicedAmount - collectedAmount);

        var purchaseOrderSpend = await rangePurchaseOrders
            .Where(x => x.Status != PurchaseOrderStatus.Cancelled)
            .SumAsync(x => (decimal?)x.Total) ?? 0m;

        var grossCashMargin = collectedAmount - purchaseOrderSpend;

        var projectsByStatus = await rangeProjects
            .GroupBy(x => x.Status)
            .Select(g => new ReportBucketDto
            {
                Label = g.Key.ToString(),
                Value = g.Count()
            })
            .OrderByDescending(x => x.Value)
            .ToListAsync();

        var revenueRows = await rangeInvoices
            .Where(x => x.Status != InvoiceStatus.Cancelled)
            .GroupBy(x => new { x.IssueDate.Year, x.IssueDate.Month })
            .Select(g => new
            {
                g.Key.Year,
                g.Key.Month,
                Value = g.Sum(x => x.Total)
            })
            .OrderBy(x => x.Year)
            .ThenBy(x => x.Month)
            .ToListAsync();

        var collectionRows = await rangePayments
            .GroupBy(x => new { x.PaymentDate.Year, x.PaymentDate.Month })
            .Select(g => new
            {
                g.Key.Year,
                g.Key.Month,
                Value = g.Sum(x => x.Amount)
            })
            .OrderBy(x => x.Year)
            .ThenBy(x => x.Month)
            .ToListAsync();

        return new ReportSummaryDto
        {
            From = start,
            To = end,
            TotalCustomers = totalCustomers,
            TotalProjects = totalProjects,
            ActiveProjects = activeProjects,
            CompletedProjects = completedProjects,
            TotalQuotations = totalQuotations,
            ApprovedQuotations = approvedQuotations,
            QuotationValue = quotationValue,
            InvoicedAmount = invoicedAmount,
            CollectedAmount = collectedAmount,
            OutstandingAmount = outstandingAmount,
            PurchaseOrderSpend = purchaseOrderSpend,
            GrossCashMargin = grossCashMargin,
            ProjectsByStatus = projectsByStatus,
            RevenueByMonth = revenueRows.Select(x => new ReportBucketDto
            {
                Label = $"{x.Year:D4}-{x.Month:D2}",
                Value = x.Value
            }).ToList(),
            CollectionsByMonth = collectionRows.Select(x => new ReportBucketDto
            {
                Label = $"{x.Year:D4}-{x.Month:D2}",
                Value = x.Value
            }).ToList()
        };
    }
}
