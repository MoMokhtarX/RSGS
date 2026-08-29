using RSGS.Api.DTOs;

namespace RSGS.Api.Interfaces;

public interface ISupplierService
{
    Task<List<SupplierResponseDto>> GetAllAsync(bool activeOnly = false);
    Task<SupplierResponseDto?> GetByIdAsync(int id);
    Task<SupplierResponseDto> CreateAsync(SupplierDto dto);
    Task<SupplierResponseDto?> UpdateAsync(int id, SupplierDto dto);
    Task<bool> SetActiveAsync(int id, bool active);
}

public interface IInvoiceService
{
    Task<List<InvoiceResponseDto>> GetAllAsync();
    Task<InvoiceResponseDto?> GetByIdAsync(int id);
    Task<InvoiceResponseDto> CreateAsync(CreateInvoiceDto dto);
    Task<InvoiceResponseDto> CreateFromQuotationAsync(int quotationId);
    Task<PaymentResponseDto> AddPaymentAsync(CreatePaymentDto dto);
    Task<List<PaymentResponseDto>> GetPaymentsAsync(int? invoiceId = null);
    Task<InstallmentResponseDto> AddInstallmentAsync(InstallmentDto dto);
    Task<List<InstallmentResponseDto>> GetInstallmentsAsync(int invoiceId);
}

public interface IPurchaseOrderService
{
    Task<List<PurchaseOrderResponseDto>> GetAllAsync();
    Task<PurchaseOrderResponseDto?> GetByIdAsync(int id);
    Task<PurchaseOrderResponseDto> CreateAsync(CreatePurchaseOrderDto dto);
    Task<PurchaseOrderResponseDto?> ReceiveAsync(int id, ReceivePurchaseOrderDto dto);
}

public interface IInventoryService
{
    Task<List<InventoryItemResponseDto>> GetAllAsync(bool lowStockOnly = false);
    Task<List<StockMovementResponseDto>> GetMovementsAsync(int? productComponentId = null);
    Task<InventoryItemResponseDto?> AdjustAsync(InventoryAdjustmentDto dto);
    Task<InventoryItemResponseDto?> SetReorderLevelAsync(int productComponentId, SetReorderLevelDto dto);
}
