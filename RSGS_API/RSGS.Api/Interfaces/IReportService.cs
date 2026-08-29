using RSGS.Api.DTOs;

namespace RSGS.Api.Interfaces;

public interface IReportService
{
    Task<ReportSummaryDto> GetSummaryAsync(DateTime? from, DateTime? to);
}
