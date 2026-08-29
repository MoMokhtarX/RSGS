using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Filters;

public sealed class ChangePasswordOwnershipFilter : IAsyncResourceFilter
{
    public async Task OnResourceExecutionAsync(
        ResourceExecutingContext context,
        ResourceExecutionDelegate next)
    {
        var currentUser =
            context.HttpContext.RequestServices
                .GetRequiredService<ICurrentUserService>();

        // Authentication itself is handled by [Authorize].
        // This filter handles ownership authorization.
        var routeIdValue =
            context.RouteData.Values["id"]?.ToString();

        if (!int.TryParse(routeIdValue, out var targetUserId))
        {
            context.Result = new BadRequestObjectResult(new
            {
                message = "Invalid user id."
            });

            return;
        }

        var isAdmin =
            string.Equals(
                currentUser.Role,
                "Admin",
                StringComparison.OrdinalIgnoreCase);

        // Admin can change any user's password.
        if (isAdmin)
        {
            await next();
            return;
        }

        // Non-admin can change ONLY their own password.
        if (currentUser.UserId != targetUserId)
        {
            context.Result = new ForbidResult();
            return;
        }

        await next();
    }
}