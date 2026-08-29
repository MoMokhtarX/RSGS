using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.DTOs;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PurchaseOrdersController : BaseApiController
{
    private readonly IPurchaseOrderService _service;
    public PurchaseOrdersController(IPurchaseOrderService service) => _service = service;

    [HttpGet]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> GetAll() => Success(await _service.GetAllAsync());

    [HttpGet("{id:int}")]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> GetById(int id)
    {
        var result = await _service.GetByIdAsync(id);
        return result == null ? NotFoundResponse("Purchase order not found.") : Success(result);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> Create(CreatePurchaseOrderDto dto) => CreatedResponse(await _service.CreateAsync(dto), "Purchase order created successfully.");

    [HttpPost("{id:int}/receive")]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> Receive(int id, ReceivePurchaseOrderDto dto)
    {
        var result = await _service.ReceiveAsync(id, dto);
        return result == null ? NotFoundResponse("Purchase order not found.") : Success(result, "Purchase order received into inventory.");
    }
}
