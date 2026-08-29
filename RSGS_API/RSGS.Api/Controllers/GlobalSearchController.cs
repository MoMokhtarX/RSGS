using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.Interfaces;
using RSGS.Api.Enums;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/search")]
[Authorize(Roles = "Admin,Sales,Engineer,Accountant,Manager")]
public class GlobalSearchController : BaseApiController
{
    private readonly IGlobalSearchService _service;
    private readonly ICurrentUserService _currentUser;

    public GlobalSearchController(
        IGlobalSearchService service,
        ICurrentUserService currentUser)
    {
        _service = service;
        _currentUser = currentUser;
    }

    [HttpGet]
    public async Task<IActionResult> Search([FromQuery] string q)
    {
        int? engineerId =
            _currentUser.Role == UserRole.Engineer.ToString()
                ? _currentUser.UserId
                : null;

        return Success(await _service.SearchAsync(q, engineerId));
    }
}