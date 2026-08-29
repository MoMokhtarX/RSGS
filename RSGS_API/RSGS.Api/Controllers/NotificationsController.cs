using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.DTOs;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotificationsController : BaseApiController
{
    private readonly INotificationService _service;

    public NotificationsController(
        INotificationService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var notifications = await _service.GetAllAsync();

        return Success(notifications);
    }

    [HttpGet("unread")]
    public async Task<IActionResult> GetUnread()
    {
        var notifications = await _service.GetUnreadAsync();

        return Success(notifications);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var notification = await _service.GetByIdAsync(id);

        if (notification == null)
            return NotFoundResponse(
                "Notification not found.");

        return Success(notification);
    }

    [HttpPost]
    public async Task<IActionResult> Create(
        [FromBody] CreateNotificationDto dto)
    {
        var notification = await _service.CreateAsync(dto);

        return CreatedResponse(
            notification,
            "Notification created successfully.");
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(
        int id,
        [FromBody] UpdateNotificationDto dto)
    {
        var notification = await _service.UpdateAsync(
            id,
            dto);

        if (notification == null)
            return NotFoundResponse(
                "Notification not found.");

        return Success(
            notification,
            "Notification updated successfully.");
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _service.DeleteAsync(id);

        if (!deleted)
            return NotFoundResponse(
                "Notification not found.");

        return Success(
            null,
            "Notification deleted successfully.");
    }

    [HttpPatch("{id:int}/read")]
    public async Task<IActionResult> MarkAsRead(int id)
    {
        var notification =
            await _service.MarkAsReadAsync(id);

        if (notification == null)
            return NotFoundResponse(
                "Notification not found.");

        return Success(
            notification,
            "Notification marked as read.");
    }

    [HttpPatch("read-all")]
    public async Task<IActionResult> MarkAllAsRead()
    {
        await _service.MarkAllAsReadAsync();

        return Success(
            null,
            "All notifications marked as read.");
    }
}