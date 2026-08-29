import 'package:flutter_test/flutter_test.dart';
import 'package:rsgs/features/quotations/models/quotation_models.dart';

void main() {
  test('quotation mapping supports snake case nested items and numeric text', () {
    final quote = QuotationModel.fromMap({
      'id': '7', 'quotation_number': 'Q-7', 'type': '2', 'status': 3,
      'customer_id': '4', 'total_price': '150.5',
      'items': [{'id': '1', 'description': 'Panel', 'item': 'P', 'category': 1, 'quantity': '2', 'unit_cost': '50', 'unit_price': 75}],
    });
    expect(quote.id, 7);
    expect(quote.type, QuotationType.offGrid);
    expect(quote.status, QuotationStatus.approved);
    expect(quote.items.single.unitCost, 50);
    expect(quote.items.single.toCreateMap()['category'], 1);
  });

  test('quotation enums and malformed optional values use safe defaults', () {
    final quote = QuotationModel.fromMap({'type': 'bad', 'status': 99, 'items': 'not-a-list'});
    expect(QuotationItemCategory.fromValue('bad'), QuotationItemCategory.other);
    expect(quote.type, QuotationType.onGrid);
    expect(quote.status, QuotationStatus.draft);
    expect(quote.items, isEmpty);
    expect(quote.capacityUnit, 'kW');
  });
}
