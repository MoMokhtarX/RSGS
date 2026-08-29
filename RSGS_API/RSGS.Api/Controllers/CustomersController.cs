using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.DTOs;
using RSGS.Api.Interfaces;
using RSGS.Api.Common;
using RSGS.Api.Models;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CustomersController : BaseApiController
{
    private readonly ICustomerService _customerService;

    public CustomersController(ICustomerService customerService)
    {
        _customerService = customerService;
    }

    // =========================
    // GET ALL CUSTOMERS
    // =========================

    [HttpGet]
    [Authorize(Roles = "Admin,Sales,Engineer,Accountant,Manager")]
    public async Task<IActionResult> GetAll(
        [FromQuery] CustomerQueryParameters parameters)
    {
        return Success(
            await _customerService.SearchAsync(parameters));
    }

    // =========================
    // GET CUSTOMER BY ID
    // =========================

    [HttpGet("{id}")]
    [Authorize(Roles = "Admin,Sales,Engineer,Accountant,Manager")]
    public async Task<IActionResult> GetById(int id)
    {
        var customer = await _customerService.GetByIdAsync(id);

        if (customer == null)
            return NotFoundResponse("Customer not found.");

        return Success(customer);
    }

    // =========================
    // CREATE CUSTOMER
    // =========================

    [HttpPost]
    [Authorize(Roles = "Admin,Sales,Manager")]
    public async Task<IActionResult> Create(CustomerDto dto)
    {
        var customer = await _customerService.CreateAsync(dto);

        return CreatedResponse(
            customer,
            "Customer created successfully.");
    }

    // =========================
    // UPDATE CUSTOMER
    // =========================

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,Sales,Manager")]
    public async Task<IActionResult> Update(int id, CustomerDto dto)
    {
        var customer = await _customerService.UpdateAsync(id, dto);

        if (customer == null)
            return NotFoundResponse("Customer not found.");

        return Success(
            customer,
            "Customer updated successfully.");
    }

    // =========================
    // DELETE CUSTOMER
    // =========================

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,Manager")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _customerService.DeleteAsync(id);

        if (!deleted)
            return NotFoundResponse();

        return Success(
            "",
            "Customer deleted successfully.");
    }
}