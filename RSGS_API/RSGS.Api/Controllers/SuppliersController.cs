using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.DTOs;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SuppliersController : BaseApiController
{
    private readonly ISupplierService _service;
    public SuppliersController(ISupplierService service) => _service = service;

    [HttpGet]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> GetAll([FromQuery] bool activeOnly = false) => Success(await _service.GetAllAsync(activeOnly));

    [HttpGet("{id:int}")]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> GetById(int id)
    {
        var result = await _service.GetByIdAsync(id);
        return result == null ? NotFoundResponse("Supplier not found.") : Success(result);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> Create(SupplierDto dto) => CreatedResponse(await _service.CreateAsync(dto), "Supplier created successfully.");

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> Update(int id, SupplierDto dto)
    {
        var result = await _service.UpdateAsync(id, dto);
        return result == null ? NotFoundResponse("Supplier not found.") : Success(result, "Supplier updated successfully.");
    }

    [HttpPut("{id:int}/{actionName}")]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> SetStatus(int id, string actionName)
    {
        if (!string.Equals(actionName, "enable", StringComparison.OrdinalIgnoreCase) && !string.Equals(actionName, "disable", StringComparison.OrdinalIgnoreCase))
            return BadRequestResponse("Action must be enable or disable.");
        var result = await _service.SetActiveAsync(id, string.Equals(actionName, "enable", StringComparison.OrdinalIgnoreCase));
        return result ? Success(null, "Supplier status updated.") : NotFoundResponse("Supplier not found.");
    }
}
