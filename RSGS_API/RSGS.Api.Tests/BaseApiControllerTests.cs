using Microsoft.AspNetCore.Mvc;
using RSGS.Api.Common;
using RSGS.Api.Controllers;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class BaseApiControllerTests
{
    [Fact]
    public void ResponseHelpers_ReturnExpectedStatusAndEnvelope()
    {
        var controller = new TestController();
        AssertEnvelope(controller.OkResponse(), 200, true, "Success");
        AssertEnvelope(controller.CreatedResponseResult(), 201, true, "Created successfully.");
        AssertEnvelope(controller.Bad(), 400, false, "Invalid");
        AssertEnvelope(controller.Missing(), 404, false, "Not Found");
        AssertEnvelope(controller.UnauthorizedResult(), 401, false, "Unauthorized");
    }

    private static void AssertEnvelope(IActionResult result, int status, bool success, string message)
    {
        var objectResult = Assert.IsAssignableFrom<ObjectResult>(result);
        Assert.Equal(status, objectResult.StatusCode);
        var envelope = Assert.IsType<ApiResponse<object?>>(objectResult.Value);
        Assert.Equal(success, envelope.Success);
        Assert.Equal(message, envelope.Message);
    }

    private sealed class TestController : BaseApiController
    {
        public IActionResult OkResponse() => Success();
        public IActionResult CreatedResponseResult() => CreatedResponse();
        public IActionResult Bad() => BadRequestResponse("Invalid");
        public IActionResult Missing() => NotFoundResponse();
        public IActionResult UnauthorizedResult() => UnauthorizedResponse();
    }
}
