namespace RSGS.Api.DTOs.ActivityLogs;

public class ActivityLogDto
{
    public int Id { get; set; }

    public int UserId { get; set; }

    public string? Username { get; set; }

    public string? FullName { get; set; }

    public string Action { get; set; } = string.Empty;

    public string Entity { get; set; } = string.Empty;

    public int EntityId { get; set; }

    public string Description { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }
}