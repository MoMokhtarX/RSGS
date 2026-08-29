enum InvoiceStatus { draft(1, 'Draft'), issued(2, 'Issued'), partiallyPaid(3, 'Partially Paid'), paid(4, 'Paid'), overdue(5, 'Overdue'), cancelled(6, 'Cancelled'); const InvoiceStatus(this.value, this.label); final int value; final String label; static InvoiceStatus fromValue(dynamic v) { final n = v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 2; return values.firstWhere((x) => x.value == n, orElse: () => InvoiceStatus.issued); } }
enum PaymentMethod { cash(1, 'Cash'), bankTransfer(2, 'Bank Transfer'), card(3, 'Card'), cheque(4, 'Cheque'), other(99, 'Other'); const PaymentMethod(this.value, this.label); final int value; final String label; static PaymentMethod fromValue(dynamic v) { final n = v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 1; return values.firstWhere((x) => x.value == n, orElse: () => PaymentMethod.other); } }

class InvoiceItemModel { const InvoiceItemModel({required this.id, this.productComponentId, required this.description, required this.quantity, required this.unit, required this.unitPrice, required this.total}); final int id; final int? productComponentId; final String description; final double quantity; final String unit; final double unitPrice; final double total; factory InvoiceItemModel.fromMap(Map<String,dynamic> m)=>InvoiceItemModel(id:_i(m['id'])??0,productComponentId:_i(m['productComponentId']),description:m['description']?.toString()??'',quantity:_d(m['quantity'])??0,unit:m['unit']?.toString()??'pcs',unitPrice:_d(m['unitPrice'])??0,total:_d(m['total'])??0); static int? _i(dynamic v)=>v is num?v.toInt():int.tryParse(v?.toString()??''); static double? _d(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??''); }

class InstallmentModel { const InstallmentModel({required this.id,required this.invoiceId,required this.dueDate,required this.amount,required this.paidAmount,required this.status}); final int id; final int invoiceId; final DateTime dueDate; final double amount; final double paidAmount; final InvoiceStatus status; double get remaining=>((amount-paidAmount).clamp(0,double.infinity)).toDouble(); factory InstallmentModel.fromMap(Map<String,dynamic> m)=>InstallmentModel(id:_i(m['id'])??0,invoiceId:_i(m['invoiceId'])??0,dueDate:_date(m['dueDate'])??DateTime.now(),amount:_d(m['amount'])??0,paidAmount:_d(m['paidAmount'])??0,status:InvoiceStatus.fromValue(m['status'])); static int? _i(dynamic v)=>v is num?v.toInt():int.tryParse(v?.toString()??''); static double? _d(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??''); static DateTime? _date(dynamic v)=>v==null?null:DateTime.tryParse(v.toString()); }

class InvoiceModel { const InvoiceModel({required this.id,required this.invoiceNumber,required this.customerId,required this.customerName,this.projectId,this.quotationId,required this.issueDate,this.dueDate,required this.status,required this.subtotal,required this.tax,required this.total,required this.paidAmount,this.notes,required this.items,this.installments=const []}); final int id; final String invoiceNumber; final int customerId; final String customerName; final int? projectId; final int? quotationId; final DateTime issueDate; final DateTime? dueDate; final InvoiceStatus status; final double subtotal; final double tax; final double total; final double paidAmount; final String? notes; final List<InvoiceItemModel> items; final List<InstallmentModel> installments; double get remaining=>((total-paidAmount).clamp(0,double.infinity)).toDouble(); factory InvoiceModel.fromMap(Map<String,dynamic> m)=>InvoiceModel(id:_i(m['id'])??0,invoiceNumber:m['invoiceNumber']?.toString()??'',customerId:_i(m['customerId'])??0,customerName:m['customerName']?.toString()??'',projectId:_i(m['projectId']),quotationId:_i(m['quotationId']),issueDate:_date(m['issueDate'])??DateTime.now(),dueDate:_date(m['dueDate']),status:InvoiceStatus.fromValue(m['status']),subtotal:_d(m['subtotal'])??0,tax:_d(m['tax'])??0,total:_d(m['total'])??0,paidAmount:_d(m['paidAmount'])??0,notes:m['notes']?.toString(),items: _parseItems(m['items']),installments: _parseInstallments(m['installments'])); static int? _i(dynamic v)=>v is num?v.toInt():int.tryParse(v?.toString()??''); static double? _d(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??''); static DateTime? _date(dynamic v)=>v==null?null:DateTime.tryParse(v.toString()); static List<InvoiceItemModel> _parseItems(dynamic value) { if (value is! List) return const <InvoiceItemModel>[]; return value.whereType<Map>().map((x)=>InvoiceItemModel.fromMap(Map<String,dynamic>.from(x))).toList(growable:false); } static List<InstallmentModel> _parseInstallments(dynamic value) { if (value is! List) return const <InstallmentModel>[]; return value.whereType<Map>().map((x)=>InstallmentModel.fromMap(Map<String,dynamic>.from(x))).toList(growable:false); } }

class PaymentModel { const PaymentModel({required this.id,required this.invoiceId,required this.invoiceNumber,required this.amount,required this.paymentDate,required this.method,this.reference,this.notes,required this.receivedByUserName}); final int id; final int invoiceId; final String invoiceNumber; final double amount; final DateTime paymentDate; final PaymentMethod method; final String? reference; final String? notes; final String receivedByUserName; factory PaymentModel.fromMap(Map<String,dynamic> m)=>PaymentModel(id:_i(m['id'])??0,invoiceId:_i(m['invoiceId'])??0,invoiceNumber:m['invoiceNumber']?.toString()??'',amount:_d(m['amount'])??0,paymentDate:_date(m['paymentDate'])??DateTime.now(),method:PaymentMethod.fromValue(m['method']),reference:m['reference']?.toString(),notes:m['notes']?.toString(),receivedByUserName:m['receivedByUserName']?.toString()??''); static int? _i(dynamic v)=>v is num?v.toInt():int.tryParse(v?.toString()??''); static double? _d(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??''); static DateTime? _date(dynamic v)=>v==null?null:DateTime.tryParse(v.toString()); }

class SupplierModel {
  const SupplierModel({
    required this.id,
    required this.code,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    this.notes,
    required this.isActive,
  });

  final int id;
  final String code;
  final String name;
  final String? contactPerson, phone, email, address, taxNumber, notes;
  final bool isActive;

  factory SupplierModel.fromMap(Map<String, dynamic> m) => SupplierModel(
        id: _i(m['id']) ?? 0,
        code: m['code']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        contactPerson: m['contactPerson']?.toString(),
        phone: m['phone']?.toString(),
        email: m['email']?.toString(),
        address: m['address']?.toString(),
        taxNumber: m['taxNumber']?.toString(),
        notes: m['notes']?.toString(),
        isActive: m['isActive'] == true,
      );

  static int? _i(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

  SupplierModel copyWith({
    int? id,
    String? code,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool? isActive,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      taxNumber: taxNumber ?? this.taxNumber,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
    );
  }
}
class InventoryItemModel { const InventoryItemModel({required this.productComponentId,required this.code,required this.productName,required this.unit,required this.quantityOnHand,required this.reorderLevel,required this.isLowStock}); final int productComponentId; final String code,productName,unit; final double quantityOnHand,reorderLevel; final bool isLowStock; factory InventoryItemModel.fromMap(Map<String,dynamic> m)=>InventoryItemModel(productComponentId:_i(m['productComponentId'])??0,code:m['code']?.toString()??'',productName:m['productName']?.toString()??'',unit:m['unit']?.toString()??'pcs',quantityOnHand:_d(m['quantityOnHand'])??0,reorderLevel:_d(m['reorderLevel'])??0,isLowStock:m['isLowStock']==true); static int? _i(dynamic v)=>v is num?v.toInt():int.tryParse(v?.toString()??''); static double? _d(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??''); }
class PurchaseOrderModel { const PurchaseOrderModel({required this.id,required this.orderNumber,required this.supplierId,required this.supplierName,required this.orderDate,this.expectedDeliveryDate,required this.status,required this.subtotal,required this.tax,required this.total}); final int id; final String orderNumber; final int supplierId; final String supplierName; final DateTime orderDate; final DateTime? expectedDeliveryDate; final int status; final double subtotal,tax,total; factory PurchaseOrderModel.fromMap(Map<String,dynamic> m)=>PurchaseOrderModel(id:_i(m['id'])??0,orderNumber:m['orderNumber']?.toString()??'',supplierId:_i(m['supplierId'])??0,supplierName:m['supplierName']?.toString()??'',orderDate:_date(m['orderDate'])??DateTime.now(),expectedDeliveryDate:_date(m['expectedDeliveryDate']),status:_i(m['status'])??1,subtotal:_d(m['subtotal'])??0,tax:_d(m['tax'])??0,total:_d(m['total'])??0); static int? _i(dynamic v)=>v is num?v.toInt():int.tryParse(v?.toString()??''); static double? _d(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??''); static DateTime? _date(dynamic v)=>v==null?null:DateTime.tryParse(v.toString()); }

enum StockMovementType {
  purchaseReceipt(1, 'Purchase Receipt'),
  projectConsumption(2, 'Project Consumption'),
  adjustmentIn(3, 'Adjustment In'),
  adjustmentOut(4, 'Adjustment Out'),
  returnToStock(5, 'Return');

  const StockMovementType(this.value, this.label);
  final int value;
  final String label;

  static StockMovementType fromValue(dynamic v) {
    final n = v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 3;
    return values.firstWhere((x) => x.value == n, orElse: () => StockMovementType.adjustmentIn);
  }
}

class StockMovementModel {
  const StockMovementModel({
    required this.id,
    required this.productComponentId,
    required this.type,
    required this.quantity,
    this.referenceType,
    this.referenceId,
    this.notes,
    required this.createdByUserName,
    required this.createdAt,
  });

  final int id;
  final int productComponentId;
  final StockMovementType type;
  final double quantity;
  final String? referenceType;
  final int? referenceId;
  final String? notes;
  final String createdByUserName;
  final DateTime createdAt;

  factory StockMovementModel.fromMap(Map<String, dynamic> m) => StockMovementModel(
        id: _i(m['id']) ?? 0,
        productComponentId: _i(m['productComponentId']) ?? 0,
        type: StockMovementType.fromValue(m['type']),
        quantity: _d(m['quantity']) ?? 0,
        referenceType: m['referenceType']?.toString(),
        referenceId: _i(m['referenceId']),
        notes: m['notes']?.toString(),
        createdByUserName: m['createdByUserName']?.toString() ?? 'System',
        createdAt: _date(m['createdAt']) ?? DateTime.now(),
      );

  static int? _i(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
  static double? _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
  static DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
}
