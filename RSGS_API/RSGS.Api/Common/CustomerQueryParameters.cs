namespace RSGS.Api.Common;

public class CustomerQueryParameters
{
    private const int MaxPageSize = 100;

    public int PageNumber { get; set; } = 1;

    private int _pageSize = 20;

    public int PageSize
    {
        get => _pageSize;
        set => _pageSize = value > MaxPageSize ? MaxPageSize : Math.Max(1, value);
    }

    public string? Search { get; set; }

    public string? Governorate { get; set; }

    public string? City { get; set; }

    public string? Channel { get; set; }

    public string? FollowUpStatus { get; set; }

    // Optional filter for privileged roles.
    // Engineer scope is NOT taken from this value; it is enforced
    // from the authenticated user's ID inside CustomerService.
    public int? AssignedUserId { get; set; }

    public string? SortBy { get; set; }

    public bool Descending { get; set; } = true;
}
