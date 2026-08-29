using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ProductsController : BaseApiController
{
    private readonly IProductComponentService _service;

    public ProductsController(IProductComponentService service)
    {
        _service = service;
    }

    [HttpGet]
    [Authorize(Roles = "Admin,Manager,Sales,Accountant")]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? search = null,
        [FromQuery] QuotationItemCategory? category = null,
        [FromQuery] bool activeOnly = false)
    {
        return Success(await _service.GetAllAsync(search, category, activeOnly));
    }

    [HttpGet("{id:int}")]
    [Authorize(Roles = "Admin,Manager,Sales,Accountant")]
    public async Task<IActionResult> GetById(int id)
    {
        var product = await _service.GetByIdAsync(id);
        return product == null
            ? NotFoundResponse("Product not found.")
            : Success(product);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,Manager")]
    public async Task<IActionResult> Create(CreateProductComponentDto dto)
    {
        var product = await _service.CreateAsync(dto);
        return CreatedResponse(product, "Product created successfully.");
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Admin,Manager")]
    public async Task<IActionResult> Update(int id, UpdateProductComponentDto dto)
    {
        var product = await _service.UpdateAsync(id, dto);
        return product == null
            ? NotFoundResponse("Product not found.")
            : Success(product, "Product updated successfully.");
    }

    [HttpPut("{id:int}/disable")]
    [Authorize(Roles = "Admin,Manager")]
    public async Task<IActionResult> Disable(int id)
    {
        return await SetActive(id, false, "Product disabled successfully.");
    }

    [HttpPut("{id:int}/enable")]
    [Authorize(Roles = "Admin,Manager")]
    public async Task<IActionResult> Enable(int id)
    {
        return await SetActive(id, true, "Product enabled successfully.");
    }

    private async Task<IActionResult> SetActive(int id, bool active, string message)
    {
        var result = await _service.SetActiveAsync(id, active);
        return result
            ? Success(message: message)
            : NotFoundResponse("Product not found.");
    }
}
