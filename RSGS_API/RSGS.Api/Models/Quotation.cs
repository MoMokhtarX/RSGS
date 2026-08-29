using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using RSGS.Api.Enums;

namespace RSGS.Api.Models;

[Table("quotations")]
public class Quotation
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Required]
    [MaxLength(50)]
    [Column("quotation_number")]
    public string QuotationNumber { get; set; } = string.Empty;

    [Required]
    [Column("quotation_type")]
    public QuotationType Type { get; set; }

    [Required]
    [Column("status")]
    public QuotationStatus Status { get; set; } = QuotationStatus.Draft;

    // Customer
    [Column("customer_id")]
    public int CustomerId { get; set; }

    [ForeignKey(nameof(CustomerId))]
    public Customer? Customer { get; set; }

    // Project
    [Column("project_id")]
    public int? ProjectId { get; set; }

    [ForeignKey(nameof(ProjectId))]
    public Project? Project { get; set; }

    // Quotation information
    [Column("quotation_date")]
    public DateTime QuotationDate { get; set; }

    [Column("valid_until")]
    public DateTime? ValidUntil { get; set; }

    [MaxLength(500)]
    [Column("system_description")]
    public string? SystemDescription { get; set; }

    [Column("system_capacity")]
    public decimal? SystemCapacity { get; set; }

    [MaxLength(20)]
    [Column("capacity_unit")]
    public string CapacityUnit { get; set; } = "kW";

    // Internal pricing
    [Column("materials_cost", TypeName = "decimal(18,2)")]
    public decimal MaterialsCost { get; set; }

    [Column("transportation_cost", TypeName = "decimal(18,2)")]
    public decimal TransportationCost { get; set; }

    [Column("installation_cost", TypeName = "decimal(18,2)")]
    public decimal InstallationCost { get; set; }

    [Column("other_cost", TypeName = "decimal(18,2)")]
    public decimal OtherCost { get; set; }

    [Column("profit_margin", TypeName = "decimal(18,2)")]
    public decimal ProfitMargin { get; set; }

    [Column("discount", TypeName = "decimal(18,2)")]
    public decimal Discount { get; set; }

    [Column("tax", TypeName = "decimal(18,2)")]
    public decimal Tax { get; set; }

    // Final price shown in quotation
    [Column("total_price", TypeName = "decimal(18,2)")]
    public decimal TotalPrice { get; set; }

    // Arabic quotation content
    [Column("introduction")]
    [MaxLength(5000)]
    public string? Introduction { get; set; }

    [Column("general_terms")]
    [MaxLength(5000)]
    public string? GeneralTerms { get; set; }

    [Column("payment_terms")]
    [MaxLength(5000)]
    public string? PaymentTerms { get; set; }

    [Column("notes")]
    [MaxLength(5000)]
    public string? Notes { get; set; }

    // Audit
    [Column("created_at")]
    public ICollection<QuotationItem> Items { get; set; }
    = new List<QuotationItem>();
    public DateTime CreatedAt { get; set; }

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; }

    // Sending audit trail. These values are internal CRM metadata.
    public DateTime? SentAt { get; set; }
    public int? SentByUserId { get; set; }
    [MaxLength(50)]
    public string? SentMethod { get; set; }
    [MaxLength(255)]
    public string? SentRecipient { get; set; }

    public ICollection<QuotationVersion> Versions { get; set; } = new List<QuotationVersion>();
}