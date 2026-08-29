namespace RSGS.Api.Common;

public class PagedResponse<T> : ApiResponse<T>
{
    public int PageNumber { get; set; }

    public int PageSize { get; set; }

    public int TotalRecords { get; set; }

    public int TotalPages { get; set; }

    public bool HasNext => PageNumber < TotalPages;

    public bool HasPrevious => PageNumber > 1;
}