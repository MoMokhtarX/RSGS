using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Logging.Abstractions;
using RSGS.Api.Exceptions;
using RSGS.Api.Middleware;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class ExceptionMiddlewareTests
{
    [Theory]
    [InlineData("business", StatusCodes.Status400BadRequest)]
    [InlineData("argument", StatusCodes.Status400BadRequest)]
    [InlineData("missing", StatusCodes.Status404NotFound)]
    [InlineData("unauthorized", StatusCodes.Status401Unauthorized)]
    [InlineData("unknown", StatusCodes.Status500InternalServerError)]
    public async Task Middleware_MapsExceptionsToSafeHttpResponses(string kind, int expectedStatus)
    {
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();
        var middleware = new ExceptionMiddleware(_ => throw ExceptionFor(kind), NullLogger<ExceptionMiddleware>.Instance, new Environment("Production"));

        await middleware.InvokeAsync(context);

        Assert.Equal(expectedStatus, context.Response.StatusCode);
        Assert.Equal("application/json", context.Response.ContentType);
        context.Response.Body.Position = 0;
        var body = await new StreamReader(context.Response.Body, Encoding.UTF8).ReadToEndAsync();
        Assert.Contains("\"Success\":false", body);
        if (kind == "unknown") Assert.DoesNotContain("unexpected test failure", body);
    }

    [Fact]
    public async Task Middleware_ExposesErrorDetailsOnlyInDevelopment()
    {
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();
        var middleware = new ExceptionMiddleware(_ => throw new InvalidOperationException("development detail"), NullLogger<ExceptionMiddleware>.Instance, new Environment("Development"));

        await middleware.InvokeAsync(context);
        context.Response.Body.Position = 0;
        var body = await new StreamReader(context.Response.Body).ReadToEndAsync();
        Assert.Contains("development detail", body);
    }

    private static Exception ExceptionFor(string kind) => kind switch
    {
        "business" => new BusinessException("rule failure"),
        "argument" => new ArgumentException("bad input"),
        "missing" => new KeyNotFoundException("not found"),
        "unauthorized" => new UnauthorizedAccessException(),
        _ => new InvalidOperationException("unexpected test failure")
    };

    private sealed class Environment(string name) : IWebHostEnvironment
    {
        public string EnvironmentName { get; set; } = name;
        public string ApplicationName { get; set; } = "Tests";
        public string WebRootPath { get; set; } = string.Empty;
        public IFileProvider WebRootFileProvider { get; set; } = new NullFileProvider();
        public string ContentRootPath { get; set; } = string.Empty;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
