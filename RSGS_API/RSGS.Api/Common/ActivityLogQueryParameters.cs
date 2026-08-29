namespace RSGS.Api.Common;

public class ActivityLogQueryParameters
{
    public int PageNumber { get; set; } = 1;

    public int PageSize { get; set; } = 20;

    public string? Search { get; set; }

    public int? UserId { get; set; }

    public string? Action { get; set; }

    public string? Entity { get; set; }

    public DateTime? From { get; set; }

    public DateTime? To { get; set; }

    public string Sort { get; set; } = "desc";
}