using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;

namespace RSGS.Api.Authorization
{
    // Grants all authorization requirements when the current user is in the Admin role.
    public class AdminAuthorizationHandler : IAuthorizationHandler
    {
        public Task HandleAsync(AuthorizationHandlerContext context)
        {
            if (context.User?.IsInRole("Admin") == true)
            {
                // Succeed every requirement so Admin bypasses other role/policy checks
                foreach (var requirement in context.Requirements.ToList())
                {
                    context.Succeed(requirement);
                }
            }

            return Task.CompletedTask;
        }
    }
}
