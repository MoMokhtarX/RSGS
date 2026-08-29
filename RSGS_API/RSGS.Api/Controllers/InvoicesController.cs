using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.DTOs;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class InvoicesController : BaseApiController
{
    private readonly IInvoiceService _service;
    public InvoicesController(IInvoiceService service) => _service = service;

    [HttpGet]
    [Authorize(Roles = "Admin,Manager,Sales,Accountant")]
    public async Task<IActionResult> GetAll() => Success(await _service.GetAllAsync());

    [HttpGet("{id:int}")]
    [Authorize(Roles = "Admin,Manager,Sales,Accountant")]
    public async Task<IActionResult> GetById(int id)
    {
        var result = await _service.GetByIdAsync(id);
        return result == null ? NotFoundResponse("Invoice not found.") : Success(result);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> Create(CreateInvoiceDto dto) => CreatedResponse(await _service.CreateAsync(dto), "Invoice created successfully.");

    [HttpPost("from-quotation/{quotationId:int}")]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> FromQuotation(int quotationId) => CreatedResponse(await _service.CreateFromQuotationAsync(quotationId), "Invoice created from quotation.");

    [HttpGet("payments")]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> GetPayments([FromQuery] int? invoiceId = null) => Success(await _service.GetPaymentsAsync(invoiceId));

    [HttpPost("payments")]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> AddPayment(CreatePaymentDto dto) => CreatedResponse(await _service.AddPaymentAsync(dto), "Payment recorded successfully.");

    [HttpGet("{invoiceId:int}/installments")]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> GetInstallments(int invoiceId) => Success(await _service.GetInstallmentsAsync(invoiceId));

    [HttpPost("installments")]
    [Authorize(Roles = "Admin,Manager,Accountant")]
    public async Task<IActionResult> AddInstallment(InstallmentDto dto) => CreatedResponse(await _service.AddInstallmentAsync(dto), "Installment created successfully.");
}
