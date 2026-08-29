using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.DTOs;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CalendarController : BaseApiController
{
    private readonly ICalendarEventService _service;

    public CalendarController(
        ICalendarEventService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var events = await _service.GetAllAsync();

        return Success(events);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var calendarEvent = await _service.GetByIdAsync(id);

        if (calendarEvent == null)
            return NotFoundResponse(
                "Calendar event not found.");

        return Success(calendarEvent);
    }

    [HttpGet("range")]
    public async Task<IActionResult> GetByDateRange(
        [FromQuery] DateTime from,
        [FromQuery] DateTime to)
    {
        var events = await _service.GetByDateRangeAsync(
            from,
            to);

        return Success(events);
    }

    [HttpGet("reference")]
    public async Task<IActionResult> GetByReference(
        [FromQuery] string referenceType,
        [FromQuery] int referenceId)
    {
        var events = await _service.GetByReferenceAsync(
            referenceType,
            referenceId);

        return Success(events);
    }

    [HttpPost]
    public async Task<IActionResult> Create(
        [FromBody] CreateCalendarEventDto dto)
    {
        var calendarEvent = await _service.CreateAsync(dto);

        return CreatedResponse(
            calendarEvent,
            "Calendar event created successfully.");
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(
        int id,
        [FromBody] UpdateCalendarEventDto dto)
    {
        var calendarEvent = await _service.UpdateAsync(
            id,
            dto);

        if (calendarEvent == null)
            return NotFoundResponse(
                "Calendar event not found.");

        return Success(
            calendarEvent,
            "Calendar event updated successfully.");
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _service.DeleteAsync(id);

        if (!deleted)
            return NotFoundResponse(
                "Calendar event not found.");

        return Success(
            null,
            "Calendar event deleted successfully.");
    }

    [HttpPatch("{id:int}/complete")]
    public async Task<IActionResult> MarkCompleted(int id)
    {
        var calendarEvent =
            await _service.MarkCompletedAsync(id);

        if (calendarEvent == null)
            return NotFoundResponse(
                "Calendar event not found.");

        return Success(
            calendarEvent,
            "Calendar event marked as completed.");
    }
}