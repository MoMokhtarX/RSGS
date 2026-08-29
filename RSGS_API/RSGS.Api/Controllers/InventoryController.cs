using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.DTOs;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class InventoryController : BaseApiController
{
    private readonly IInventoryService _service;
    public InventoryController(IInventoryService service) => _service = service;

    [HttpGet]
    [Authorize(Roles = "Admin,Manager,Accountant,Engineer")]
    public async Task<IActionResult> GetAll([FromQuery] bool lowStockOnly = false) => Success(await _service.GetAllAsync(lowStockOnly));

    [HttpGet("movements")]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> GetMovements([FromQuery] int? productComponentId = null) => Success(await _service.GetMovementsAsync(productComponentId));

    [HttpPost("adjust")]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> Adjust(InventoryAdjustmentDto dto)
    {
        var result = await _service.AdjustAsync(dto);
        return result == null ? NotFoundResponse("Product not found.") : Success(result, "Inventory adjusted successfully.");
    }

    [HttpPut("{productComponentId:int}/reorder-level")]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> SetReorderLevel(int productComponentId, SetReorderLevelDto dto)
    {
        var result = await _service.SetReorderLevelAsync(productComponentId, dto);
        return result == null ? NotFoundResponse("Product not found.") : Success(result, "Reorder level updated.");
    }
}
