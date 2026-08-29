namespace RSGS.Api.Common;

public class ListQueryParameters
{
    private const int MaxPageSize = 100;

    public int PageNumber { get; set; } = 1;

    private int _pageSize = 20;
    public int PageSize
    {
        get => _pageSize;
        set => _pageSize = Math.Clamp(value, 1, MaxPageSize);
    }

    public string? Search { get; set; }
    public string? SortBy { get; set; }
    public bool Descending { get; set; } = true;
}

public class QuotationQueryParameters : ListQueryParameters
{
    public string? Status { get; set; }
    public string? Type { get; set; }
    public int? CustomerId { get; set; }
    public int? ProjectId { get; set; }
}
