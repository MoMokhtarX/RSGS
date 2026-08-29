using RSGS.Api.DTOs;
using RSGS.Api.Enums;

namespace RSGS.Api.Interfaces;

public interface IProductComponentService
{
    Task<List<ProductComponentResponseDto>> GetAllAsync(
        string? search = null,
        QuotationItemCategory? category = null,
        bool activeOnly = false);

    Task<ProductComponentResponseDto?> GetByIdAsync(int id);

    Task<ProductComponentResponseDto> CreateAsync(CreateProductComponentDto dto);

    Task<ProductComponentResponseDto?> UpdateAsync(int id, UpdateProductComponentDto dto);

    Task<bool> SetActiveAsync(int id, bool isActive);
}
