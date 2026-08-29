using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.Common;
using RSGS.Api.DTOs;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Controllers;

[Authorize]
[Route("api/ActivityLogs")]
[Route("api/Activity")]
[ApiController]
public class ActivityLogsController : BaseApiController
{
    private readonly IActivityLogService _service;
    private readonly ICurrentUserService _currentUser;

    public ActivityLogsController(
        IActivityLogService service,
        ICurrentUserService currentUser)
    {
        _service = service;
        _currentUser = currentUser;
    }

    // Activity history is an Admin-only screen in the current application.
    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll(
        [FromQuery] ActivityLogQueryParameters parameters)
    {
        var result = await _service.SearchAsync(parameters);
        return Success(result);
    }

    // Used by the current Flutter client for Login/Logout activity.
    // The authenticated user id is always used instead of trusting the
    // userId sent by the client.
    [HttpPost]
    public async Task<IActionResult> Create(
        [FromBody] CreateActivityLogDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Action))
        {
            return BadRequest("Activity action is required.");
        }

        var entity = !string.IsNullOrWhiteSpace(dto.EntityType)
            ? dto.EntityType!
            : dto.Entity ?? "System";

        var description = !string.IsNullOrWhiteSpace(dto.Details)
            ? dto.Details!
            : dto.Description ?? string.Empty;

        var log = await _service.CreateAsync(
            _currentUser.UserId,
            dto.Action.Trim(),
            entity.Trim(),
            dto.EntityId ?? 0,
            description.Trim());

        return Success(new
        {
            id = log.Id,
            createdAt = log.CreatedAt
        });
    }
}
