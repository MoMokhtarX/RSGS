using RSGS.Api.Enums;

namespace RSGS.Api.DTOs;

public class QuotationResponseDto
{
    public int Id { get; set; }

    public string QuotationNumber { get; set; } = string.Empty;

    public QuotationType Type { get; set; }

    public QuotationStatus Status { get; set; }

    public int CustomerId { get; set; }

    public int? ProjectId { get; set; }

    public DateTime QuotationDate { get; set; }

    public DateTime? ValidUntil { get; set; }

    public string? SystemDescription { get; set; }

    public decimal? SystemCapacity { get; set; }

    public string CapacityUnit { get; set; } = "kW";

    public decimal TotalPrice { get; set; }

    // Internal pricing — used by the internal CRM when editing/reviewing a quotation.
    // These values are not customer-facing quotation content.
    public decimal MaterialsCost { get; set; }
    public decimal TransportationCost { get; set; }
    public decimal InstallationCost { get; set; }
    public decimal OtherCost { get; set; }
    public decimal ProfitMargin { get; set; }
    public decimal Discount { get; set; }
    public decimal Tax { get; set; }

    public string? Introduction { get; set; }

    public string? GeneralTerms { get; set; }

    public string? PaymentTerms { get; set; }

    public string? Notes { get; set; }

    public DateTime? SentAt { get; set; }
    public int? SentByUserId { get; set; }
    public string? SentMethod { get; set; }
    public string? SentRecipient { get; set; }

    public List<QuotationItemResponseDto> Items { get; set; } = new();
}