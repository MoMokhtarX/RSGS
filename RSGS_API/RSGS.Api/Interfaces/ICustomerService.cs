using RSGS.Api.Common;
using RSGS.Api.DTOs;
using RSGS.Api.Models;

namespace RSGS.Api.Interfaces;

public interface ICustomerService
{
    Task<List<CustomerResponseDto>> GetAllAsync();

    Task<CustomerResponseDto?> GetByIdAsync(int id);

    Task<CustomerResponseDto> CreateAsync(CustomerDto dto);

    Task<CustomerResponseDto?> UpdateAsync(int id, CustomerDto dto);

    Task<bool> DeleteAsync(int id);

    Task<PagedResult<CustomerResponseDto>> SearchAsync(
        CustomerQueryParameters parameters);
}