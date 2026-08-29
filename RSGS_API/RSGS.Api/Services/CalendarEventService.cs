using RSGS.Api.DTOs;
using RSGS.Api.Exceptions;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Repositories.Interfaces;
using RSGS.Api.Utilities;

namespace RSGS.Api.Services;

public class CalendarEventService : ICalendarEventService
{
    private readonly ICalendarEventRepository _repository;

    public CalendarEventService(
        ICalendarEventRepository repository)
    {
        _repository = repository;
    }

    public async Task<IEnumerable<CalendarEventDto>> GetAllAsync()
    {
        var events = await _repository.GetAllAsync();

        return events
            .OrderBy(x => x.EventDate)
            .Select(MapToDto);
    }

    public async Task<CalendarEventDto?> GetByIdAsync(int id)
    {
        var calendarEvent = await _repository.GetByIdAsync(id);

        return calendarEvent == null
            ? null
            : MapToDto(calendarEvent);
    }

    public async Task<IEnumerable<CalendarEventDto>> GetByDateRangeAsync(
        DateTime from,
        DateTime to)
    {
        from = DateTimeUtility.ToUtc(from);
        to = DateTimeUtility.ToUtc(to);

        if (from > to)
            throw new BusinessException(
                "The start date cannot be greater than the end date.");

        var events = await _repository.GetByDateRangeAsync(from, to);

        return events.Select(MapToDto);
    }

    public async Task<IEnumerable<CalendarEventDto>> GetByReferenceAsync(
        string referenceType,
        int referenceId)
    {
        if (string.IsNullOrWhiteSpace(referenceType))
            throw new BusinessException(
                "Reference type is required.");

        if (referenceId <= 0)
            throw new BusinessException(
                "Reference ID must be greater than zero.");

        var events = await _repository.GetByReferenceAsync(
            referenceType,
            referenceId);

        return events.Select(MapToDto);
    }

    public async Task<CalendarEventDto> CreateAsync(
        CreateCalendarEventDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Title))
            throw new BusinessException(
                "Calendar event title is required.");

        var calendarEvent = new CalendarEvent
        {
            Title = dto.Title.Trim(),
            Description = dto.Description,
            EventDate = DateTimeUtility.ToUtc(dto.EventDate),
            Type = dto.Type,
            IsCompleted = false,
            ReferenceId = dto.ReferenceId,
            ReferenceType = dto.ReferenceType,
            CreatedAt = DateTime.UtcNow
        };

        await _repository.AddAsync(calendarEvent);

        return MapToDto(calendarEvent);
    }

    public async Task<CalendarEventDto?> UpdateAsync(
        int id,
        UpdateCalendarEventDto dto)
    {
        var calendarEvent = await _repository.GetByIdAsync(id);

        if (calendarEvent == null)
            return null;

        if (string.IsNullOrWhiteSpace(dto.Title))
            throw new BusinessException(
                "Calendar event title is required.");

        calendarEvent.Title = dto.Title.Trim();
        calendarEvent.Description = dto.Description;
        calendarEvent.EventDate = DateTimeUtility.ToUtc(dto.EventDate);
        calendarEvent.Type = dto.Type;
        calendarEvent.IsCompleted = dto.IsCompleted;
        calendarEvent.ReferenceId = dto.ReferenceId;
        calendarEvent.ReferenceType = dto.ReferenceType;

        await _repository.UpdateAsync(calendarEvent);

        return MapToDto(calendarEvent);
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var calendarEvent = await _repository.GetByIdAsync(id);

        if (calendarEvent == null)
            return false;

        await _repository.DeleteAsync(calendarEvent);

        return true;
    }

    public async Task<CalendarEventDto?> MarkCompletedAsync(int id)
    {
        var calendarEvent = await _repository.GetByIdAsync(id);

        if (calendarEvent == null)
            return null;

        calendarEvent.IsCompleted = true;

        await _repository.UpdateAsync(calendarEvent);

        return MapToDto(calendarEvent);
    }

    private static CalendarEventDto MapToDto(
        CalendarEvent calendarEvent)
    {
        return new CalendarEventDto
        {
            Id = calendarEvent.Id,
            Title = calendarEvent.Title,
            Description = calendarEvent.Description,
            EventDate = calendarEvent.EventDate,
            Type = calendarEvent.Type,
            IsCompleted = calendarEvent.IsCompleted,
            ReferenceId = calendarEvent.ReferenceId,
            ReferenceType = calendarEvent.ReferenceType,
            CreatedAt = calendarEvent.CreatedAt
        };
    }
}