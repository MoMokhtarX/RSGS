using System.ComponentModel.DataAnnotations;

namespace RSGS.Api.DTOs;

public class CreateCustomerFollowUpDto
{
    [Required, MaxLength(50)] public string Type { get; set; } = "Call";
    public DateTime ScheduledAt { get; set; }
    [MaxLength(30)] public string Status { get; set; } = "Pending";
    [MaxLength(2000)] public string? Notes { get; set; }
}

public class UpdateCustomerFollowUpDto : CreateCustomerFollowUpDto
{
    public DateTime? CompletedAt { get; set; }
}

public class CustomerFollowUpResponseDto
{
    public int Id { get; set; }
    public int CustomerId { get; set; }
    public int UserId { get; set; }
    public string? UserName { get; set; }
    public string Type { get; set; } = "Call";
    public DateTime ScheduledAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public string Status { get; set; } = "Pending";
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class CreateCustomerInteractionDto
{
    [Required, MaxLength(50)] public string Type { get; set; } = "Note";
    [MaxLength(200)] public string? Subject { get; set; }
    [Required, MaxLength(5000)] public string Details { get; set; } = string.Empty;
    public DateTime? OccurredAt { get; set; }
}

public class CustomerInteractionResponseDto
{
    public int Id { get; set; }
    public int CustomerId { get; set; }
    public int UserId { get; set; }
    public string? UserName { get; set; }
    public string Type { get; set; } = "Note";
    public string? Subject { get; set; }
    public string Details { get; set; } = string.Empty;
    public DateTime OccurredAt { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class GlobalSearchResultDto
{
    public string Type { get; set; } = string.Empty;
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Subtitle { get; set; } = string.Empty;
    public string Route { get; set; } = string.Empty;
}

public class QuotationVersionResponseDto
{
    public int Id { get; set; }
    public int QuotationId { get; set; }
    public int VersionNumber { get; set; }
    public int CreatedByUserId { get; set; }
    public string? CreatedByUserName { get; set; }
    public string Reason { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public object? Snapshot { get; set; }
}

public class QuotationSendTrackingDto
{
    [MaxLength(50)] public string Method { get; set; } = "Manual";
    [MaxLength(255)] public string? Recipient { get; set; }
}
