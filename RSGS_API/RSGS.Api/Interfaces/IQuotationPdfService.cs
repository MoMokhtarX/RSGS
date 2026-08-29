using RSGS.Api.DTOs;

namespace RSGS.Api.Interfaces;

public interface IQuotationPdfService
{
    Task<byte[]> GenerateQuotationPdfAsync(int quotationId);
}