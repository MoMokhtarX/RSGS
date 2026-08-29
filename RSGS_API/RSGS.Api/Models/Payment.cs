using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using RSGS.Api.Enums;

namespace RSGS.Api.Models;

[Table("payments")]
public class Payment
{
    [Key] public int Id { get; set; }
    public int InvoiceId { get; set; }
    [Column(TypeName = "decimal(18,2)")] public decimal Amount { get; set; }
    public DateTime PaymentDate { get; set; }
    public PaymentMethod Method { get; set; }
    [MaxLength(100)] public string? Reference { get; set; }
    [MaxLength(2000)] public string? Notes { get; set; }
    public int ReceivedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }
    public Invoice Invoice { get; set; } = null!;
    public User ReceivedByUser { get; set; } = null!;
}
