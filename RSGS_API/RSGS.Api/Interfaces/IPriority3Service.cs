using RSGS.Api.DTOs;

namespace RSGS.Api.Interfaces;

public interface ICustomerActivityService
{
    Task<List<CustomerFollowUpResponseDto>> GetFollowUpsAsync(int customerId);
    Task<CustomerFollowUpResponseDto> CreateFollowUpAsync(int customerId, CreateCustomerFollowUpDto dto);
    Task<CustomerFollowUpResponseDto?> UpdateFollowUpAsync(int id, UpdateCustomerFollowUpDto dto);
    Task<bool> DeleteFollowUpAsync(int id);
    Task<List<CustomerInteractionResponseDto>> GetInteractionsAsync(int customerId);
    Task<CustomerInteractionResponseDto> CreateInteractionAsync(int customerId, CreateCustomerInteractionDto dto);
}

public interface IGlobalSearchService
{
    Task<List<GlobalSearchResultDto>> SearchAsync(string query, int? engineerId);
}

public interface IQuotationVersionService
{
    Task CreateSnapshotAsync(Models.Quotation quotation, int userId, string reason);
    Task<List<QuotationVersionResponseDto>> GetHistoryAsync(int quotationId);
}
