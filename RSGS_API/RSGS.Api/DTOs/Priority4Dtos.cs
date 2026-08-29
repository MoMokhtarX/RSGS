using System.ComponentModel.DataAnnotations;
using RSGS.Api.Enums;

namespace RSGS.Api.DTOs;

public class SupplierDto
{
    [Required, MinLength(2), MaxLength(50)] public string Code { get; set; } = string.Empty;
    [Required, MinLength(2), MaxLength(250)] public string Name { get; set; } = string.Empty;
    [MaxLength(200)] public string? ContactPerson { get; set; }
    [MaxLength(30)] public string? Phone { get; set; }
    [EmailAddress, MaxLength(255)] public string? Email { get; set; }
    [MaxLength(500)] public string? Address { get; set; }
    [MaxLength(100)] public string? TaxNumber { get; set; }
    [MaxLength(2000)] public string? Notes { get; set; }
    public bool IsActive { get; set; } = true;
}

public class SupplierResponseDto : SupplierDto
{
    public int Id { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class InvoiceItemDto
{
    public int? ProductComponentId { get; set; }
    [Required, MaxLength(500)] public string Description { get; set; } = string.Empty;
    [Range(0.001, 100000000)] public decimal Quantity { get; set; } = 1;
    [MaxLength(50)] public string Unit { get; set; } = "pcs";
    [Range(0, 1000000000)] public decimal UnitPrice { get; set; }
    public int SortOrder { get; set; }
}

public class CreateInvoiceDto
{
    [Required] public int CustomerId { get; set; }
    public int? ProjectId { get; set; }
    public int? QuotationId { get; set; }
    public DateTime? IssueDate { get; set; }
    public DateTime? DueDate { get; set; }
    [Range(0, 1000000000)] public decimal Tax { get; set; }
    [MaxLength(5000)] public string? Notes { get; set; }
    [EnumDataType(typeof(InvoiceStatus))]
    //[EnumDataType(typeof(InvoiceStatus))]
    public InvoiceStatus Status { get; set; } = InvoiceStatus.Issued;
    [MinLength(1)] public List<InvoiceItemDto> Items { get; set; } = new();
}

public class InvoiceResponseDto
{
    public int Id { get; set; }
    public string InvoiceNumber { get; set; } = string.Empty;
    public int CustomerId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public int? ProjectId { get; set; }
    public int? QuotationId { get; set; }
    public DateTime IssueDate { get; set; }
    public DateTime? DueDate { get; set; }
    [EnumDataType(typeof(InvoiceStatus))]
    public InvoiceStatus Status { get; set; }
    public decimal Subtotal { get; set; }
    public decimal Tax { get; set; }
    public decimal Total { get; set; }
    public decimal PaidAmount { get; set; }
    public decimal RemainingAmount => Math.Max(0, Total - PaidAmount);
    public string? Notes { get; set; }
    public List<InvoiceItemResponseDto> Items { get; set; } = new();
    public List<InstallmentResponseDto> Installments { get; set; } = new();
}

public class InvoiceItemResponseDto
{
    public int Id { get; set; }
    public int? ProductComponentId { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Quantity { get; set; }
    public string Unit { get; set; } = "pcs";
    public decimal UnitPrice { get; set; }
    public decimal Total { get; set; }
    public int SortOrder { get; set; }
}

public class CreatePaymentDto
{
    [Required] public int InvoiceId { get; set; }
    [Range(0.01, 1000000000)] public decimal Amount { get; set; }
    public DateTime? PaymentDate { get; set; }
    [EnumDataType(typeof(PaymentMethod))]
    //[EnumDataType(typeof(PaymentMethod))]
    public PaymentMethod Method { get; set; } = PaymentMethod.Cash;
    [MaxLength(100)] public string? Reference { get; set; }
    [MaxLength(2000)] public string? Notes { get; set; }
}

public class PaymentResponseDto
{
    public int Id { get; set; }
    public int InvoiceId { get; set; }
    public string InvoiceNumber { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public DateTime PaymentDate { get; set; }
    [EnumDataType(typeof(PaymentMethod))]
    public PaymentMethod Method { get; set; }
    public string? Reference { get; set; }
    public string? Notes { get; set; }
    public int ReceivedByUserId { get; set; }
    public string ReceivedByUserName { get; set; } = string.Empty;
}

public class InstallmentDto
{
    [Required] public int InvoiceId { get; set; }
    public DateTime DueDate { get; set; }
    [Range(0.01, 1000000000)] public decimal Amount { get; set; }
}

public class InstallmentResponseDto
{
    public int Id { get; set; }
    public int InvoiceId { get; set; }
    public DateTime DueDate { get; set; }
    public decimal Amount { get; set; }
    public decimal PaidAmount { get; set; }
    [EnumDataType(typeof(InvoiceStatus))]
    public InvoiceStatus Status { get; set; }
}

public class PurchaseOrderItemDto
{
    [Required] public int ProductComponentId { get; set; }
    [Range(0.001, 100000000)] public decimal Quantity { get; set; }
    [Range(0, 1000000000)] public decimal UnitCost { get; set; }
}

public class CreatePurchaseOrderDto
{
    [Required] public int SupplierId { get; set; }
    public DateTime? OrderDate { get; set; }
    public DateTime? ExpectedDeliveryDate { get; set; }
    [Range(0, 1000000000)] public decimal Tax { get; set; }
    [MaxLength(5000)] public string? Notes { get; set; }
    [MinLength(1)] public List<PurchaseOrderItemDto> Items { get; set; } = new();
}

public class PurchaseOrderResponseDto
{
    public int Id { get; set; }
    public string OrderNumber { get; set; } = string.Empty;
    public int SupplierId { get; set; }
    public string SupplierName { get; set; } = string.Empty;
    public DateTime OrderDate { get; set; }
    public DateTime? ExpectedDeliveryDate { get; set; }
    [EnumDataType(typeof(PurchaseOrderStatus))]
    public PurchaseOrderStatus Status { get; set; }
    public decimal Subtotal { get; set; }
    public decimal Tax { get; set; }
    public decimal Total { get; set; }
    public string? Notes { get; set; }
    public List<PurchaseOrderItemResponseDto> Items { get; set; } = new();
}

public class PurchaseOrderItemResponseDto
{
    public int Id { get; set; }
    public int ProductComponentId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public decimal Quantity { get; set; }
    public decimal ReceivedQuantity { get; set; }
    public decimal UnitCost { get; set; }
    public decimal Total { get; set; }
}

public class ReceivePurchaseOrderItemDto
{
    [Required] public int PurchaseOrderItemId { get; set; }
    [Range(0.001, 100000000)] public decimal Quantity { get; set; }
}

public class ReceivePurchaseOrderDto
{
    [MinLength(1)] public List<ReceivePurchaseOrderItemDto> Items { get; set; } = new();
}

public class InventoryItemResponseDto
{
    public int ProductComponentId { get; set; }
    public string Code { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;
    public string Unit { get; set; } = "pcs";
    public decimal QuantityOnHand { get; set; }
    public decimal ReorderLevel { get; set; }
    public bool IsLowStock => QuantityOnHand <= ReorderLevel;
}

public class InventoryAdjustmentDto
{
    [Required] public int ProductComponentId { get; set; }
    [Range(0.001, 100000000)] public decimal Quantity { get; set; }
    public bool Increase { get; set; }
    [MaxLength(2000)] public string? Notes { get; set; }
}

public class StockMovementResponseDto
{
    public int Id { get; set; }
    public int ProductComponentId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    [EnumDataType(typeof(StockMovementType))]
    public StockMovementType Type { get; set; }
    public decimal Quantity { get; set; }
    public string? ReferenceType { get; set; }
    public int? ReferenceId { get; set; }
    public string? Notes { get; set; }
    public string CreatedByUserName { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

public class SetReorderLevelDto
{
    [Range(0, 100000000)] public decimal ReorderLevel { get; set; }
}
