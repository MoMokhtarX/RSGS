namespace RSGS.Api.DTOs;

public sealed class ReportSummaryDto
{
    public DateTime From { get; init; }
    public DateTime To { get; init; }
    public int TotalCustomers { get; init; }
    public int TotalProjects { get; init; }
    public int ActiveProjects { get; init; }
    public int CompletedProjects { get; init; }
    public int TotalQuotations { get; init; }
    public int ApprovedQuotations { get; init; }
    public decimal QuotationValue { get; init; }
    public decimal InvoicedAmount { get; init; }
    public decimal CollectedAmount { get; init; }
    public decimal OutstandingAmount { get; init; }
    public decimal PurchaseOrderSpend { get; init; }
    public decimal GrossCashMargin { get; init; }
    public IReadOnlyList<ReportBucketDto> ProjectsByStatus { get; init; } = [];
    public IReadOnlyList<ReportBucketDto> RevenueByMonth { get; init; } = [];
    public IReadOnlyList<ReportBucketDto> CollectionsByMonth { get; init; } = [];
}

public sealed class ReportBucketDto
{
    public string Label { get; init; } = string.Empty;
    public decimal Value { get; init; }
}
