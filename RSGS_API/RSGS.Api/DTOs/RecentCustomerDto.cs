namespace RSGS.Api.DTOs;

public class RecentCustomerDto
{
    public int Id { get; set; }

    public string Name { get; set; } = "";

    public string Phone { get; set; } = "";

    public DateTime CreatedAt { get; set; }
}