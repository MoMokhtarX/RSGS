using System.ComponentModel.DataAnnotations;
using RSGS.Api.Enums;

namespace RSGS.Api.DTOs;

public class CreateCalendarEventDto
{
    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public DateTime EventDate { get; set; }

    [EnumDataType(typeof(CalendarEventType))]
    public CalendarEventType Type { get; set; }

    public int? ReferenceId { get; set; }

    public string? ReferenceType { get; set; }
}