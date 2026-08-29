using System.ComponentModel.DataAnnotations.Schema;

namespace RSGS.Api.Models;

[Table("inventory_stock")]
public class InventoryStock
{
    public int Id { get; set; }
    public int ProductComponentId { get; set; }
    [Column(TypeName = "decimal(18,3)")] public decimal QuantityOnHand { get; set; }
    [Column(TypeName = "decimal(18,3)")] public decimal ReorderLevel { get; set; }
    public DateTime UpdatedAt { get; set; }
    public ProductComponent ProductComponent { get; set; } = null!;
}
