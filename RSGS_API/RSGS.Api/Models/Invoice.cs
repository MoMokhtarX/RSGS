using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using RSGS.Api.Enums;

namespace RSGS.Api.Models;

[Table("invoices")]
public class Invoice
{
    [Key] public int Id { get; set; }
    [Required, MaxLength(50)] public string InvoiceNumber { get; set; } = string.Empty;
    public int CustomerId { get; set; }
    public int? ProjectId { get; set; }
    public int? QuotationId { get; set; }
    public DateTime IssueDate { get; set; }
    public DateTime? DueDate { get; set; }
    public InvoiceStatus Status { get; set; } = InvoiceStatus.Draft;
    [Column(TypeName = "decimal(18,2)")] public decimal Subtotal { get; set; }
    [Column(TypeName = "decimal(18,2)")] public decimal Tax { get; set; }
    [Column(TypeName = "decimal(18,2)")] public decimal Total { get; set; }
    [Column(TypeName = "decimal(18,2)")] public decimal PaidAmount { get; set; }
    [MaxLength(5000)] public string? Notes { get; set; }
    public int CreatedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Customer Customer { get; set; } = null!;
    public Project? Project { get; set; }
    public Quotation? Quotation { get; set; }
    public User CreatedByUser { get; set; } = null!;
    public ICollection<InvoiceItem> Items { get; set; } = new List<InvoiceItem>();
    public ICollection<Payment> Payments { get; set; } = new List<Payment>();
    public ICollection<Installment> Installments { get; set; } = new List<Installment>();
}
