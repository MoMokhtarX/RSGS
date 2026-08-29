using System.ComponentModel.DataAnnotations;
using RSGS.Api.Enums;

namespace RSGS.Api.DTOs;

public class QuotationItemDto
{
    public int? ProductComponentId { get; set; }

    [Required]
    [MinLength(2)]
    [MaxLength(500)]
    public string Description { get; set; } = string.Empty;

    [Required]
    [MinLength(2)]
    [MaxLength(300)]
    public string Item { get; set; } = string.Empty;

    [Required]
    [EnumDataType(typeof(QuotationItemCategory))]
    public QuotationItemCategory Category { get; set; }

    [Range(0.01, 1000000)]
    public decimal? Quantity { get; set; }

    [MaxLength(50)]
    public string? Unit { get; set; }

    [MaxLength(100)]
    public string? CountryOfOrigin { get; set; }

    // Optional for manually entered lines. When ProductComponentId is set,
    // the API always uses the current catalog cost/selling price instead.
    [Range(0, 1000000000)]
    public decimal? UnitCost { get; set; }

    [Range(0, 1000000000)]
    public decimal? UnitPrice { get; set; }

    [Range(0, int.MaxValue)]
    public int SortOrder { get; set; }

    [MaxLength(2000)]
    public string? InternalNotes { get; set; }
}
