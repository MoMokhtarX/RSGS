namespace RSGS.Api.Common;

public class ProjectQueryParameters : ListQueryParameters
{
    public string? Status { get; set; }
    public int? EngineerId { get; set; }
    public int? CustomerId { get; set; }
    public string? Governorate { get; set; }
    public string? City { get; set; }
}
