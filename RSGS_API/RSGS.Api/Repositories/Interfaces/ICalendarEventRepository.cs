using RSGS.Api.Models;

namespace RSGS.Api.Repositories.Interfaces;

public interface ICalendarEventRepository
    : IGenericRepository<CalendarEvent>
{
    Task<IEnumerable<CalendarEvent>> GetByDateRangeAsync(
        DateTime from,
        DateTime to);

    Task<IEnumerable<CalendarEvent>> GetByReferenceAsync(
        string referenceType,
        int referenceId);
}