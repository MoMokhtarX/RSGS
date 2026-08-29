using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.Common;
using RSGS.Api.Enums;
using RSGS.Api.Interfaces;
using RSGS.Api.Services;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api")]
[Authorize]
public class PagedListsController : BaseApiController
{
    private readonly IPagedListService _service;
    private readonly ICurrentUserService _currentUser;

    public PagedListsController(
        IPagedListService service,
        ICurrentUserService currentUser)
    {
        _service = service;
        _currentUser = currentUser;
    }

    [HttpGet("Projects/paged")]
    [Authorize(Roles = "Admin,Sales,Engineer,Accountant,Manager")]
    public async Task<IActionResult> Projects(
        [FromQuery] ProjectQueryParameters parameters)
    {
        int? engineerId =
            _currentUser.Role == UserRole.Engineer.ToString()
                ? _currentUser.UserId
                : null;

        return Success(
            await _service.GetProjectsAsync(parameters, engineerId));
    }

    [HttpGet("Quotations/paged")]
    [Authorize(Roles = "Admin,Sales,Engineer,Accountant,Manager")]
    public async Task<IActionResult> Quotations(
        [FromQuery] QuotationQueryParameters parameters)
    {
        int? engineerId =
            _currentUser.Role == UserRole.Engineer.ToString()
                ? _currentUser.UserId
                : null;

        return Success(
            await _service.GetQuotationsAsync(parameters, engineerId));
    }
}