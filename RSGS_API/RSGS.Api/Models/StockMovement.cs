using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using RSGS.Api.Enums;

namespace RSGS.Api.Models;

[Table("stock_movements")]
public class StockMovement
{
    [Key] public int Id { get; set; }
    public int ProductComponentId { get; set; }
    public StockMovementType Type { get; set; }
    [Column(TypeName = "decimal(18,3)")] public decimal Quantity { get; set; }
    [MaxLength(50)] public string? ReferenceType { get; set; }
    public int? ReferenceId { get; set; }
    [MaxLength(2000)] public string? Notes { get; set; }
    public int CreatedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }
    public ProductComponent ProductComponent { get; set; } = null!;
    public User CreatedByUser { get; set; } = null!;
}
