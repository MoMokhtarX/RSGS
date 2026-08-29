using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.DTOs;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/Customers/{customerId:int}")]
[Authorize(Roles = "Admin,Sales,Engineer,Accountant,Manager")]
public class CustomerActivitiesController : BaseApiController
{
    private readonly ICustomerActivityService _service;
    public CustomerActivitiesController(ICustomerActivityService service) => _service = service;

    [HttpGet("follow-ups")]
    public async Task<IActionResult> GetFollowUps(int customerId) => Success(await _service.GetFollowUpsAsync(customerId));

    [HttpPost("follow-ups")]
    [Authorize(Roles = "Admin,Sales,Engineer,Manager")]
    public async Task<IActionResult> CreateFollowUp(int customerId, CreateCustomerFollowUpDto dto) =>
        CreatedResponse(await _service.CreateFollowUpAsync(customerId, dto), "Follow-up created successfully.");

    [HttpPut("follow-ups/{id:int}")]
    [Authorize(Roles = "Admin,Sales,Engineer,Manager")]
    public async Task<IActionResult> UpdateFollowUp(int customerId, int id, UpdateCustomerFollowUpDto dto) =>
        (await _service.UpdateFollowUpAsync(id, dto)) is { } result
            ? Success(result, "Follow-up updated successfully.")
            : NotFoundResponse("Follow-up not found.");

    [HttpDelete("follow-ups/{id:int}")]
    [Authorize(Roles = "Admin,Sales,Engineer,Manager")]
    public async Task<IActionResult> DeleteFollowUp(int customerId, int id) =>
        await _service.DeleteFollowUpAsync(id) ? Success(null, "Follow-up deleted successfully.") : NotFoundResponse("Follow-up not found.");

    [HttpGet("interactions")]
    public async Task<IActionResult> GetInteractions(int customerId) => Success(await _service.GetInteractionsAsync(customerId));

    [HttpPost("interactions")]
    [Authorize(Roles = "Admin,Sales,Engineer,Manager")]
    public async Task<IActionResult> CreateInteraction(int customerId, CreateCustomerInteractionDto dto) =>
        CreatedResponse(await _service.CreateInteractionAsync(customerId, dto), "Interaction created successfully.");
}
