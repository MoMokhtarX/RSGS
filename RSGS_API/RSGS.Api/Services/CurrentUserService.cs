using System.Security.Claims;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Services;

public class CurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CurrentUserService(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    private ClaimsPrincipal? User => _httpContextAccessor.HttpContext?.User;

    public bool IsAuthenticated => User?.Identity?.IsAuthenticated ?? false;

    public int UserId
    {
        get
        {
            var value = User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            return int.TryParse(value, out var id) ? id : 0;
        }
    }

    public string Username => User?.FindFirst(ClaimTypes.Name)?.Value ?? string.Empty;

    public string Role => User?.FindFirst(ClaimTypes.Role)?.Value ?? string.Empty;
}
