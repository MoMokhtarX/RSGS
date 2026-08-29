namespace RSGS.Api.DTOs;

public class CreateActivityLogDto
{
    // Kept for compatibility with the current Flutter payload.
    // The API does not trust this value; it uses the authenticated user.
    public int? UserId { get; set; }

    public string Action { get; set; } = string.Empty;

    // Flutter currently sends entityType.
    public string? EntityType { get; set; }

    // Also accept entity for future clients.
    public string? Entity { get; set; }

    public int? EntityId { get; set; }

    // Flutter currently sends details.
    public string? Details { get; set; }

    // Also accept description for future clients.
    public string? Description { get; set; }
}
