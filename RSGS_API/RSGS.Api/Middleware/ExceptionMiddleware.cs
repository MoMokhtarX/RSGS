using System.Net;
using System.Text.Json;
using RSGS.Api.Exceptions;
using RSGS.Api.Common;

namespace RSGS.Api.Middleware;

public class ExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionMiddleware> _logger;
    private readonly IWebHostEnvironment _environment;

    public ExceptionMiddleware(
        RequestDelegate next,
        ILogger<ExceptionMiddleware> logger,
        IWebHostEnvironment environment)
    {
        _next = next;
        _logger = logger;
        _environment = environment;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unhandled exception occurred.");

            context.Response.ContentType = "application/json";

            var statusCode = GetStatusCode(ex);

            context.Response.StatusCode = statusCode;

            var response = new ApiResponse<object?>
            {
                Success = false,
                Message = GetErrorMessage(ex),
                Data = null,
                Errors = null
            };

            await context.Response.WriteAsync(
                JsonSerializer.Serialize(response));
        }
    }

    private static int GetStatusCode(Exception ex)
    {
        return ex switch
        {
            BusinessException =>
                (int)HttpStatusCode.BadRequest,

            ArgumentException =>
                (int)HttpStatusCode.BadRequest,

            KeyNotFoundException =>
                (int)HttpStatusCode.NotFound,

            UnauthorizedAccessException =>
                (int)HttpStatusCode.Unauthorized,

            _ =>
                (int)HttpStatusCode.InternalServerError
        };
    }

    private string GetErrorMessage(Exception ex)
    {
        if (_environment.IsDevelopment())
            return ex.Message;

        return ex switch
        {
            BusinessException =>
                ex.Message,

            ArgumentException =>
                ex.Message,

            KeyNotFoundException =>
                ex.Message,

            UnauthorizedAccessException =>
                "You are not authorized to perform this action.",

            _ =>
                "An unexpected error occurred."
        };
    }
}