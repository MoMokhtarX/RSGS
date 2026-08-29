using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RSGS.Api.Models;

[Table("quotation_versions")]
public class QuotationVersion
{
    [Key]
    public int Id { get; set; }

    [Required]
    public int QuotationId { get; set; }

    [ForeignKey(nameof(QuotationId))]
    public Quotation Quotation { get; set; } = null!;

    public int VersionNumber { get; set; }

    public int CreatedByUserId { get; set; }

    [ForeignKey(nameof(CreatedByUserId))]
    public User CreatedByUser { get; set; } = null!;

    [Required]
    public string SnapshotJson { get; set; } = string.Empty;

    [MaxLength(100)]
    public string Reason { get; set; } = "Update";

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
