using QuestPDF.Fluent;
using RSGS.Api.Interfaces;
using RSGS.Api.PDF;
using RSGS.Api.Repositories.Interfaces;

namespace RSGS.Api.Services;

public class QuotationPdfService : IQuotationPdfService
{
    private readonly IQuotationService _quotationService;
    private readonly ICustomerRepository _customerRepository;
    private readonly IProjectRepository _projectRepository;

    public QuotationPdfService(
        IQuotationService quotationService,
        ICustomerRepository customerRepository,
        IProjectRepository projectRepository)
    {
        _quotationService = quotationService;
        _customerRepository = customerRepository;
        _projectRepository = projectRepository;
    }

    public async Task<byte[]> GenerateQuotationPdfAsync(int quotationId)
    {
        var quotation =
            await _quotationService.GetByIdAsync(quotationId);

        if (quotation == null)
            throw new Exception("Quotation not found.");

        var customer =
            await _customerRepository.GetByIdAsync(quotation.CustomerId);

        if (customer == null)
            throw new Exception("Customer not found.");

        var project = quotation.ProjectId.HasValue
            ? await _projectRepository.GetByIdAsync(quotation.ProjectId.Value)
            : null;

        var document = new QuotationPdfDocument(
            quotation,
            customer,
            project);

        return document.GeneratePdf();
    }
}