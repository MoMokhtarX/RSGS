using RSGS.Api.Enums;

namespace RSGS.Api.DTOs;

public class QuotationItemResponseDto
{
    public int Id { get; set; }
    public int? ProductComponentId { get; set; }
    public string? ProductCode { get; set; }
    public string? ProductName { get; set; }
    public string Description { get; set; } = string.Empty;
    public string Item { get; set; } = string.Empty;
    public QuotationItemCategory Category { get; set; }
    public decimal? Quantity { get; set; }
    public string? Unit { get; set; }
    public string? CountryOfOrigin { get; set; }
    public decimal? UnitCost { get; set; }
    public decimal? UnitPrice { get; set; }
    public decimal TotalCost { get; set; }
    public decimal TotalPrice { get; set; }
    public int SortOrder { get; set; }
    public string? InternalNotes { get; set; }
}
