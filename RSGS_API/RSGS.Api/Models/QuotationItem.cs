using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using RSGS.Api.Enums;

namespace RSGS.Api.Models;

public class QuotationItem
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Required]
    [Column("quotation_id")]
    public int QuotationId { get; set; }

    [Column("product_component_id")]
    public int? ProductComponentId { get; set; }

    [Required]
    [Column("description")]
    [MaxLength(500)]
    public string Description { get; set; } = string.Empty;

    [Required]
    [Column("item")]
    [MaxLength(300)]
    public string Item { get; set; } = string.Empty;

    [Required]
    [Column("category")]
    public QuotationItemCategory Category { get; set; }

    [Column("quantity")]
    public decimal? Quantity { get; set; }

    [Column("unit")]
    [MaxLength(50)]
    public string? Unit { get; set; }

    [Column("country_of_origin")]
    [MaxLength(100)]
    public string? CountryOfOrigin { get; set; }

    // Snapshot of the catalog prices at quotation time.
    [Column("unit_cost", TypeName = "decimal(18,2)")]
    public decimal? UnitCost { get; set; }

    [Column("unit_price", TypeName = "decimal(18,2)")]
    public decimal? UnitPrice { get; set; }

    [Column("total_cost", TypeName = "decimal(18,2)")]
    public decimal TotalCost { get; set; }

    [Column("total_price", TypeName = "decimal(18,2)")]
    public decimal TotalPrice { get; set; }

    [Column("sort_order")]
    public int SortOrder { get; set; }

    [Column("internal_notes")]
    [MaxLength(2000)]
    public string? InternalNotes { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; }

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; }

    public Quotation Quotation { get; set; } = null!;

    [ForeignKey(nameof(ProductComponentId))]
    public ProductComponent? ProductComponent { get; set; }
}
