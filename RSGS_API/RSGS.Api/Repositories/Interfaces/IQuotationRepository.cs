using RSGS.Api.Models;

namespace RSGS.Api.Repositories.Interfaces;

public interface IQuotationRepository : IGenericRepository<Quotation>
{
    Task<Quotation?> GetDetailsAsync(int id);

    Task<List<Quotation>> GetAllScopedAsync(int? engineerId);

    Task<Quotation?> GetByQuotationNumberAsync(
        string quotationNumber);

    Task UpdateWithItemsAsync(Quotation quotation);
}