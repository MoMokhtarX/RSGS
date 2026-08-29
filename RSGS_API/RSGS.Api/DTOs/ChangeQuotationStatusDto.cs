using System.ComponentModel.DataAnnotations;
using RSGS.Api.Enums;

namespace RSGS.Api.DTOs;

public class ChangeQuotationStatusDto
{
    [Required]
    [EnumDataType(typeof(QuotationStatus))]
    public QuotationStatus Status { get; set; }

    public QuotationSendTrackingDto? Tracking { get; set; }
}