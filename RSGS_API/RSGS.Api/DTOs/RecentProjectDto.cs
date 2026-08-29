using RSGS.Api.Enums;

namespace RSGS.Api.DTOs;

public class RecentProjectDto
{
    public int Id { get; set; }

    public string ProjectNumber { get; set; } = "";

    public string Name { get; set; } = "";

    public ProjectStatus ProjectStatus { get; set; }

    public decimal TotalValue { get; set; }

    public DateTime CreatedDate { get; set; }
}