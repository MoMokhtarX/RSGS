using RSGS.Api.Enums;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RSGS.Api.Models;

[Table("users")]
public class User
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("username")]
    [MaxLength(100)]
    public string Username { get; set; } = string.Empty;

    [Column("password_hash")]
    [MaxLength(500)]
    public string PasswordHash { get; set; } = string.Empty;

    [Column("full_name")]
    [MaxLength(200)]
    public string FullName { get; set; } = string.Empty;

    [Column("email")]
    [MaxLength(200)]
    public string Email { get; set; } = string.Empty;

    [Column("role")]
    public UserRole Role { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; }

    public ICollection<Customer> Customers { get; set; } = new List<Customer>();

    public ICollection<Project> Projects { get; set; } = new List<Project>();

    public ICollection<ActivityLog> ActivityLogs { get; set; } = new List<ActivityLog>();

}