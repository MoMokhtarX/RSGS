using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.Models;
using RSGS.Api.Repositories.Interfaces;

namespace RSGS.Api.Repositories;

public class CalendarEventRepository
    : GenericRepository<CalendarEvent>,
      ICalendarEventRepository
{

    public CalendarEventRepository(AppDbContext context)
        : base(context){}

    public async Task<IEnumerable<CalendarEvent>> GetByDateRangeAsync(
        DateTime from,
        DateTime to)
    {
        return await _context.CalendarEvents
            .AsNoTracking()
            .Where(x =>
                x.EventDate >= from &&
                x.EventDate <= to)
            .OrderBy(x => x.EventDate)
            .ToListAsync();
    }

    public async Task<IEnumerable<CalendarEvent>> GetByReferenceAsync(
        string referenceType,
        int referenceId)
    {
        return await _context.CalendarEvents
            .AsNoTracking()
            .Where(x =>
                x.ReferenceType == referenceType &&
                x.ReferenceId == referenceId)
            .OrderBy(x => x.EventDate)
            .ToListAsync();
    }
}