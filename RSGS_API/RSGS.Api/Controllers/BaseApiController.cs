using Microsoft.AspNetCore.Mvc;
using RSGS.Api.Common;

namespace RSGS.Api.Controllers;

public abstract class BaseApiController : ControllerBase
{
    protected IActionResult Success(
        object? data = null,
        string message = "Success")
    {
        return Ok(new ApiResponse<object?>
        {
            Success = true,
            Message = message,
            Data = data,
            Errors = null
        });
    }

    protected IActionResult CreatedResponse(
        object? data = null,
        string message = "Created successfully.")
    {
        return StatusCode(
            StatusCodes.Status201Created,
            new ApiResponse<object?>
            {
                Success = true,
                Message = message,
                Data = data,
                Errors = null
            });
    }

    protected IActionResult BadRequestResponse(
        string message,
        object? errors = null)
    {
        return BadRequest(
            new ApiResponse<object?>
            {
                Success = false,
                Message = message,
                Data = null,
                Errors = errors
            });
    }

    protected IActionResult NotFoundResponse(
        string message = "Not Found")
    {
        return NotFound(
            new ApiResponse<object?>
            {
                Success = false,
                Message = message,
                Data = null,
                Errors = null
            });
    }

    protected IActionResult UnauthorizedResponse(
        string message = "Unauthorized")
    {
        return Unauthorized(
            new ApiResponse<object?>
            {
                Success = false,
                Message = message,
                Data = null,
                Errors = null
            });
    }
}