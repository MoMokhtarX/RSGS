using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RSGS.Api.Models;

[Table("activity_logs")]
public class ActivityLog
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Required]
    [Column("user_id")]
    public int UserId { get; set; }

    [ForeignKey(nameof(UserId))]
    public User User { get; set; } = null!;

    [Required]
    [Column("action")]
    public string Action { get; set; } = string.Empty;

    [Required]
    [Column("entity")]
    public string Entity { get; set; } = string.Empty;

    [Column("entity_id")]
    public int EntityId { get; set; }

    [Column("description")]
    public string Description { get; set; } = string.Empty;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}