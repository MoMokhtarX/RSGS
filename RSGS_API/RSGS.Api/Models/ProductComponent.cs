using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using RSGS.Api.Enums;

namespace RSGS.Api.Models;

[Table("product_components")]
public class ProductComponent
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Required]
    [MaxLength(50)]
    [Column("code")]
    public string Code { get; set; } = string.Empty;

    [Required]
    [MaxLength(250)]
    [Column("name")]
    public string Name { get; set; } = string.Empty;

    [Required]
    [Column("category")]
    public QuotationItemCategory Category { get; set; }

    [MaxLength(150)]
    [Column("brand")]
    public string? Brand { get; set; }

    [MaxLength(150)]
    [Column("model")]
    public string? Model { get; set; }

    [MaxLength(1000)]
    [Column("specification")]
    public string? Specification { get; set; }

    [Required]
    [MaxLength(50)]
    [Column("unit")]
    public string Unit { get; set; } = "pcs";

    [MaxLength(100)]
    [Column("country_of_origin")]
    public string? CountryOfOrigin { get; set; }

    [Column("cost_price", TypeName = "decimal(18,2)")]
    public decimal CostPrice { get; set; }

    [Column("selling_price", TypeName = "decimal(18,2)")]
    public decimal SellingPrice { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; } = true;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; }

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; }

    public ICollection<QuotationItem> QuotationItems { get; set; } = new List<QuotationItem>();
    public InventoryStock? InventoryStock { get; set; }
    public ICollection<PurchaseOrderItem> PurchaseOrderItems { get; set; } = new List<PurchaseOrderItem>();
    public ICollection<InvoiceItem> InvoiceItems { get; set; } = new List<InvoiceItem>();
    public ICollection<StockMovement> StockMovements { get; set; } = new List<StockMovement>();
}
