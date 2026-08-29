using RSGS.Api.Common;
using RSGS.Api.Models;

namespace RSGS.Api.Repositories.Interfaces;

public interface ICustomerRepository : IGenericRepository<Customer>
{
    Task<Customer?> GetWithProjectsAsync(
        int id,
        int? assignedUserId = null);

    Task<PagedResult<Customer>> SearchAsync(
        CustomerQueryParameters parameters,
        int? assignedUserId = null);
}
