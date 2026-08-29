using System.ComponentModel.DataAnnotations;
using RSGS.Api.Enums;

namespace RSGS.Api.DTOs;

public class UpdateNotificationDto
{
    public string Title { get; set; } = string.Empty;

    public string Message { get; set; } = string.Empty;

    [EnumDataType(typeof(NotificationType))]
    public NotificationType Type { get; set; }

    public bool IsRead { get; set; }

    public DateTime? ScheduledFor { get; set; }
}