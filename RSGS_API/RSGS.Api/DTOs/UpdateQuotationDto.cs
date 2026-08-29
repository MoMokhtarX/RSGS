using System.ComponentModel.DataAnnotations;
using RSGS.Api.Enums;

namespace RSGS.Api.DTOs;

public class UpdateQuotationDto
{
    [Required]
    [EnumDataType(typeof(QuotationType))]
    public QuotationType Type { get; set; }

    [Range(1, int.MaxValue)]
    public int CustomerId { get; set; }

    public int? ProjectId { get; set; }

    public DateTime? QuotationDate { get; set; }

    public DateTime? ValidUntil { get; set; }

    [MaxLength(5000)]
    public string? SystemDescription { get; set; }

    [Range(0.01, 1000000000)]
    public decimal? SystemCapacity { get; set; }

    [MaxLength(100)]
    public string CapacityUnit { get; set; } = "kW";

    [MaxLength(5000)]
    public string? Introduction { get; set; }

    [MaxLength(5000)]
    public string? GeneralTerms { get; set; }

    [MaxLength(5000)]
    public string? PaymentTerms { get; set; }

    [MaxLength(5000)]
    public string? Notes { get; set; }

    [Required]
    public List<QuotationItemDto> Items { get; set; } = new();

    [Range(0, 1000000000)]
    public decimal MaterialsCost { get; set; }

    [Range(0, 1000000000)]
    public decimal TransportationCost { get; set; }

    [Range(0, 1000000000)]
    public decimal InstallationCost { get; set; }

    [Range(0, 1000000000)]
    public decimal OtherCost { get; set; }

    [Range(0, 100)]
    public decimal ProfitMargin { get; set; }

    [Range(0, 1000000000)]
    public decimal Discount { get; set; }

    [Range(0, 100)]
    public decimal Tax { get; set; }
}
