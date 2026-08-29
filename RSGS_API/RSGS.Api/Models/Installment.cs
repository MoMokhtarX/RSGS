using System.ComponentModel.DataAnnotations.Schema;
using RSGS.Api.Enums;

namespace RSGS.Api.Models;

[Table("installments")]
public class Installment
{
    public int Id { get; set; }
    public int InvoiceId { get; set; }
    public DateTime DueDate { get; set; }
    [Column(TypeName = "decimal(18,2)")] public decimal Amount { get; set; }
    [Column(TypeName = "decimal(18,2)")] public decimal PaidAmount { get; set; }
    public InvoiceStatus Status { get; set; } = InvoiceStatus.Issued;
    public Invoice Invoice { get; set; } = null!;
}
