using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.DTOs;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class QuotationsController : BaseApiController
{
    private readonly IQuotationService _quotationService;
    private readonly IQuotationPdfService _quotationPdfService;

    public QuotationsController(
        IQuotationService quotationService,
        IQuotationPdfService quotationPdfService)
    {
        _quotationService = quotationService;
        _quotationPdfService = quotationPdfService;
    }

    // =========================
    // GET ALL QUOTATIONS
    // =========================

    [HttpGet]
    [Authorize(Roles = "Admin,Sales,Engineer,Accountant,Manager")]
    public async Task<IActionResult> GetAll()
    {
        var quotations = await _quotationService.GetAllAsync();

        return Success(quotations);
    }

    // =========================
    // GET QUOTATION BY ID
    // =========================

    [HttpGet("{id:int}")]
    [Authorize(Roles = "Admin,Sales,Engineer,Accountant,Manager")]
    public async Task<IActionResult> GetById(int id)
    {
        var quotation = await _quotationService.GetByIdAsync(id);

        if (quotation == null)
            return NotFoundResponse("Quotation not found.");

        return Success(quotation);
    }

    // =========================
    // CREATE QUOTATION
    // =========================

    [HttpPost]
    [Authorize(Roles = "Admin,Sales,Manager")]
    public async Task<IActionResult> Create(
        [FromBody] CreateQuotationDto dto)
    {
        var quotation = await _quotationService.CreateAsync(dto);

        return CreatedResponse(
            quotation,
            "Quotation created successfully.");
    }

    // =========================
    // UPDATE QUOTATION
    // =========================

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Admin,Sales,Manager")]
    public async Task<IActionResult> Update(
        int id,
        [FromBody] UpdateQuotationDto dto)
    {
        var quotation = await _quotationService.UpdateAsync(id, dto);

        if (quotation == null)
            return NotFoundResponse("Quotation not found.");

        return Success(
            quotation,
            "Quotation updated successfully.");
    }

    // =========================
    // DELETE QUOTATION
    // =========================

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Admin,Manager")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _quotationService.DeleteAsync(id);

        if (!deleted)
            return NotFoundResponse("Quotation not found.");

        return Success(
            null,
            "Quotation deleted successfully.");
    }

    // =========================
    // CHANGE QUOTATION STATUS
    // =========================

    [HttpPatch("{id:int}/status")]
    [Authorize(Roles = "Admin,Sales,Manager")]
    public async Task<IActionResult> ChangeStatus(
        int id,
        [FromBody] ChangeQuotationStatusDto dto)
    {
        var quotation = await _quotationService.ChangeStatusAsync(
            id,
            dto.Status,
            dto.Tracking);

        if (quotation == null)
            return NotFoundResponse("Quotation not found.");

        return Success(
            quotation,
            "Quotation status updated successfully.");
    }

    // =========================
    // GENERATE PDF
    // =========================

    [HttpGet("{id:int}/pdf")]
    [Authorize(Roles = "Admin,Sales,Engineer,Accountant,Manager")]
    public async Task<IActionResult> GeneratePdf(int id)
    {
        var pdf =
            await _quotationPdfService.GenerateQuotationPdfAsync(id);

        return File(
            pdf,
            "application/pdf",
            $"Quotation-{id}.pdf");
    }
}