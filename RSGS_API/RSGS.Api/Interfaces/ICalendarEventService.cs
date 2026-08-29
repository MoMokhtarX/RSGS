using RSGS.Api.DTOs;

namespace RSGS.Api.Interfaces;

public interface ICalendarEventService
{
    Task<IEnumerable<CalendarEventDto>> GetAllAsync();

    Task<CalendarEventDto?> GetByIdAsync(int id);

    Task<IEnumerable<CalendarEventDto>> GetByDateRangeAsync(
        DateTime from,
        DateTime to);

    Task<IEnumerable<CalendarEventDto>> GetByReferenceAsync(
        string referenceType,
        int referenceId);

    Task<CalendarEventDto> CreateAsync(
        CreateCalendarEventDto dto);

    Task<CalendarEventDto?> UpdateAsync(
        int id,
        UpdateCalendarEventDto dto);

    Task<bool> DeleteAsync(int id);

    Task<CalendarEventDto?> MarkCompletedAsync(int id);
}