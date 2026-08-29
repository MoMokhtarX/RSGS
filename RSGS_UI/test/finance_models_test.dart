import 'package:flutter_test/flutter_test.dart';
import 'package:rsgs/features/finance/models/finance_models.dart';

void main() {
  test('finance enums use safe defaults and supported API values', () {
    expect(InvoiceStatus.fromValue('4'), InvoiceStatus.paid);
    expect(InvoiceStatus.fromValue('invalid'), InvoiceStatus.issued);
    expect(PaymentMethod.fromValue(2), PaymentMethod.bankTransfer);
    expect(PaymentMethod.fromValue(77), PaymentMethod.other);
  });

  test('invoice mapping parses nested data and clamps remaining values', () {
    final invoice = InvoiceModel.fromMap({
      'id': '1', 'invoiceNumber': 'INV-1', 'customerId': 2, 'customerName': 'Customer',
      'issueDate': '2026-01-01T00:00:00Z', 'status': 3, 'subtotal': '100', 'tax': 14,
      'total': 114, 'paidAmount': 200,
      'items': [{'id': 1, 'description': 'Panel', 'quantity': '2', 'unitPrice': '50', 'total': '100'}],
      'installments': [{'id': 1, 'invoiceId': 1, 'dueDate': '2026-02-01', 'amount': 50, 'paidAmount': 20, 'status': 3}],
    });
    expect(invoice.status, InvoiceStatus.partiallyPaid);
    expect(invoice.items.single.quantity, 2);
    expect(invoice.installments.single.remaining, 30);
    expect(invoice.remaining, 0);
  });

  test('inventory and purchase order mappings tolerate malformed optional values', () {
    final inventory = InventoryItemModel.fromMap({'productComponentId': '7', 'quantityOnHand': '1.5', 'reorderLevel': 2, 'isLowStock': true});
    final order = PurchaseOrderModel.fromMap({'id': 1, 'orderNumber': 'PO-1', 'supplierId': 2, 'supplierName': 'S', 'orderDate': 'bad', 'total': '5'});
    expect(inventory.productComponentId, 7);
    expect(inventory.isLowStock, isTrue);
    expect(order.total, 5);
  });
}
