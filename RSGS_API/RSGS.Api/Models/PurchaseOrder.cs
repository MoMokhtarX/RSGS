using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using RSGS.Api.Enums;

namespace RSGS.Api.Models;

[Table("purchase_orders")]
public class PurchaseOrder
{
    [Key] public int Id { get; set; }
    [Required, MaxLength(50)] public string OrderNumber { get; set; } = string.Empty;
    public int SupplierId { get; set; }
    public DateTime OrderDate { get; set; }
    public DateTime? ExpectedDeliveryDate { get; set; }
    public PurchaseOrderStatus Status { get; set; } = PurchaseOrderStatus.Draft;
    [Column(TypeName = "decimal(18,2)")] public decimal Subtotal { get; set; }
    [Column(TypeName = "decimal(18,2)")] public decimal Tax { get; set; }
    [Column(TypeName = "decimal(18,2)")] public decimal Total { get; set; }
    [MaxLength(5000)] public string? Notes { get; set; }
    public int CreatedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public Supplier Supplier { get; set; } = null!;
    public User CreatedByUser { get; set; } = null!;
    public ICollection<PurchaseOrderItem> Items { get; set; } = new List<PurchaseOrderItem>();
}
