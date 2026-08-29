import 'package:flutter_test/flutter_test.dart';
import 'package:rsgs/features/customer_activity/models/customer_activity_models.dart';
import 'package:rsgs/features/products/models/product_models.dart';

void main() {
  test('product mapping accepts API casing and cleans optional display fields', () {
    final product = ProductComponentModel.fromMap({
      'id': '3', 'code': 'P-3', 'name': 'Panel', 'category': '1', 'brand': ' Brand ', 'model': ' ',
      'unit': 'pcs', 'cost_price': '15.5', 'sellingPrice': 20, 'is_active': true,
    });
    expect(product.id, 3);
    expect(product.category, ProductCategory.solarPanels);
    expect(product.displayName, 'Panel — Brand');
    expect(product.costPrice, 15.5);
    expect(product.isActive, isTrue);
  });

  test('product category and malformed model fields use safe fallbacks', () {
    final product = ProductComponentModel.fromMap({'category': 'unknown', 'costPrice': 'bad'});
    expect(ProductCategory.fromValue(14), ProductCategory.cablePipes);
    expect(product.category, ProductCategory.other);
    expect(product.costPrice, 0);
    expect(product.unit, 'pcs');
  });

  test('customer activity models retain valid fields and safely default missing values', () {
    final followUp = CustomerFollowUpModel.fromMap({'id': 1, 'customerId': 2, 'userId': 3, 'scheduledAt': '2026-01-01', 'createdAt': '2026-01-01'});
    final interaction = CustomerInteractionModel.fromMap({'id': 4, 'customerId': 2, 'userId': 3, 'details': 'Called', 'occurredAt': '2026-01-01', 'createdAt': '2026-01-01'});
    expect(followUp.status, 'Pending');
    expect(interaction.type, 'Note');
    expect(interaction.details, 'Called');
  });
}
