using System.Reflection;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Routing;
using RSGS.Api.Controllers;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class ControllerAuthorizationContractTests
{
    [Fact]
    public void EveryHttpEndpoint_IsProtectedOrExplicitlyAnonymous()
    {
        var controllers = typeof(BaseApiController).Assembly.GetTypes()
            .Where(type => !type.IsAbstract && typeof(ControllerBase).IsAssignableFrom(type));
        var unprotected = new List<string>();

        foreach (var controller in controllers)
        {
            var controllerProtected = controller.IsDefined(typeof(AuthorizeAttribute), true);
            foreach (var action in controller.GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.DeclaredOnly)
                         .Where(method => method.GetCustomAttributes().OfType<HttpMethodAttribute>().Any()))
            {
                var explicitlyAnonymous = action.IsDefined(typeof(AllowAnonymousAttribute), true);
                var actionProtected = action.IsDefined(typeof(AuthorizeAttribute), true);
                if (!explicitlyAnonymous && !controllerProtected && !actionProtected)
                    unprotected.Add($"{controller.Name}.{action.Name}");
            }
        }

        Assert.Empty(unprotected);
    }
}
