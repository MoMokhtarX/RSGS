using RSGS.Api.Middleware;

namespace RSGS.Api.Extensions;

public static class MiddlewareExtensions
{
    public static IApplicationBuilder UseExceptionMiddleware(
        this IApplicationBuilder app)
    {
        return app.UseMiddleware<ExceptionMiddleware>();
    }
}