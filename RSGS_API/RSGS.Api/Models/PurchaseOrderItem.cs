using System.ComponentModel.DataAnnotations.Schema;

namespace RSGS.Api.Models;

[Table("purchase_order_items")]
public class PurchaseOrderItem
{
    public int Id { get; set; }
    public int PurchaseOrderId { get; set; }
    public int ProductComponentId { get; set; }
    [Column(TypeName = "decimal(18,3)")] public decimal Quantity { get; set; }
    [Column(TypeName = "decimal(18,3)")] public decimal ReceivedQuantity { get; set; }
    [Column(TypeName = "decimal(18,2)")] public decimal UnitCost { get; set; }
    [Column(TypeName = "decimal(18,2)")] public decimal Total { get; set; }
    public PurchaseOrder PurchaseOrder { get; set; } = null!;
    public ProductComponent ProductComponent { get; set; } = null!;
}
