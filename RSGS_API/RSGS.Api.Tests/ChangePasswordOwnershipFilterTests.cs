using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using RSGS.Api.Filters;
using RSGS.Api.Interfaces;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class ChangePasswordOwnershipFilterTests
{
    [Theory]
    [InlineData("invalid", "Admin", 1, typeof(BadRequestObjectResult))]
    [InlineData("2", "Sales", 1, typeof(ForbidResult))]
    [InlineData("2", "Admin", 1, null)]
    [InlineData("2", "Sales", 2, null)]
    public async Task Filter_EnforcesOwnershipAndAdminOverride(string routeId, string role, int userId, Type? expectedResult)
    {
        var services = new ServiceCollection().AddSingleton<ICurrentUserService>(new CurrentUser(userId, role)).BuildServiceProvider();
        var http = new DefaultHttpContext { RequestServices = services };
        var routeData = new RouteData(); routeData.Values["id"] = routeId;
        var actionContext = new ActionContext(http, routeData, new Microsoft.AspNetCore.Mvc.Abstractions.ActionDescriptor());
        var context = new ResourceExecutingContext(actionContext, [], []);
        var invoked = false;

        await new ChangePasswordOwnershipFilter().OnResourceExecutionAsync(context, () =>
        {
            invoked = true;
            return Task.FromResult(new ResourceExecutedContext(actionContext, []));
        });

        if (expectedResult is null) Assert.True(invoked);
        else Assert.IsType(expectedResult, context.Result);
    }

    private sealed class CurrentUser(int id, string role) : ICurrentUserService
    {
        public int UserId => id;
        public string Role => role;
        public string Username => "test";
        public bool IsAuthenticated => true;
    }
}
