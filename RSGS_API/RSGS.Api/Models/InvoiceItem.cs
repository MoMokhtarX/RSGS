using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RSGS.Api.Models;

[Table("invoice_items")]
public class InvoiceItem
{
    [Key] public int Id { get; set; }
    public int InvoiceId { get; set; }
    public int? ProductComponentId { get; set; }
    [Required, MaxLength(500)] public string Description { get; set; } = string.Empty;
    [Column(TypeName = "decimal(18,3)")] public decimal Quantity { get; set; } = 1;
    [MaxLength(50)] public string Unit { get; set; } = "pcs";
    [Column(TypeName = "decimal(18,2)")] public decimal UnitPrice { get; set; }
    [Column(TypeName = "decimal(18,2)")] public decimal Total { get; set; }
    public int SortOrder { get; set; }
    public Invoice Invoice { get; set; } = null!;
    public ProductComponent? ProductComponent { get; set; }
}
