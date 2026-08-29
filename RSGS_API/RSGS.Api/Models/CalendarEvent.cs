using RSGS.Api.Enums;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RSGS.Api.Models;

[Table("calendar_events")]
public class CalendarEvent
{
    [Key]
    public int Id { get; set; }

    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public DateTime EventDate { get; set; }

    public CalendarEventType Type { get; set; }

    public bool IsCompleted { get; set; }

    public int? ReferenceId { get; set; }

    public string? ReferenceType { get; set; }

    public DateTime CreatedAt { get; set; }
}