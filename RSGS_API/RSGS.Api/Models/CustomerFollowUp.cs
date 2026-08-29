using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RSGS.Api.Models;

[Table("customer_follow_ups")]
public class CustomerFollowUp
{
    [Key]
    public int Id { get; set; }

    [Required]
    public int CustomerId { get; set; }

    [ForeignKey(nameof(CustomerId))]
    public Customer Customer { get; set; } = null!;

    public int UserId { get; set; }

    [ForeignKey(nameof(UserId))]
    public User User { get; set; } = null!;

    [Required, MaxLength(50)]
    public string Type { get; set; } = "Call";

    public DateTime ScheduledAt { get; set; }

    public DateTime? CompletedAt { get; set; }

    [Required, MaxLength(30)]
    public string Status { get; set; } = "Pending";

    [MaxLength(2000)]
    public string? Notes { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
