using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RSGS.Api.Models;

[Table("suppliers")]
public class Supplier
{
    [Key] public int Id { get; set; }
    [Required, MaxLength(50)] public string Code { get; set; } = string.Empty;
    [Required, MaxLength(250)] public string Name { get; set; } = string.Empty;
    [MaxLength(200)] public string? ContactPerson { get; set; }
    [MaxLength(30)] public string? Phone { get; set; }
    [MaxLength(255)] public string? Email { get; set; }
    [MaxLength(500)] public string? Address { get; set; }
    [MaxLength(100)] public string? TaxNumber { get; set; }
    [MaxLength(2000)] public string? Notes { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public ICollection<PurchaseOrder> PurchaseOrders { get; set; } = new List<PurchaseOrder>();
}
