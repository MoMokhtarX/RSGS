using RSGS.Api.DTOs;
using RSGS.Api.Enums;

namespace RSGS.Api.Interfaces;

public interface IQuotationService
{
    Task<List<QuotationResponseDto>> GetAllAsync();

    Task<QuotationResponseDto?> GetByIdAsync(int id);

    Task<QuotationResponseDto> CreateAsync(
        CreateQuotationDto dto);

    Task<QuotationResponseDto?> UpdateAsync(
        int id,
        UpdateQuotationDto dto);

    Task<bool> DeleteAsync(int id);

    Task<QuotationResponseDto?> ChangeStatusAsync(
        int id,
        QuotationStatus status,
        QuotationSendTrackingDto? tracking = null);
}