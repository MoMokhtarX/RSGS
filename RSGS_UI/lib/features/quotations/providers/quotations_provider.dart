import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';

import '../data/quotations_repository.dart';
import '../models/quotation_models.dart';

final quotationsProvider =
FutureProvider<List<QuotationModel>>(
      (ref) {
    ref.watch(dataRefreshVersionProvider);
    return ref
        .watch(quotationsRepositoryProvider)
        .getAll();
  },
);

final customerQuotationsProvider = FutureProvider.family<List<QuotationModel>, int>((ref, customerId) async {
  ref.watch(dataRefreshVersionProvider);
  final all = await ref.watch(quotationsProvider.future);
  return all.where((q) => q.customerId == customerId).toList();
});

final projectQuotationsProvider = FutureProvider.family<List<QuotationModel>, int>((ref, projectId) async {
  ref.watch(dataRefreshVersionProvider);
  final all = await ref.watch(quotationsProvider.future);
  return all.where((q) => q.projectId == projectId).toList();
});

final quotationProvider =
FutureProvider.family<
    QuotationModel?,
    int>(
      (ref, id) {
    ref.watch(dataRefreshVersionProvider);
    return ref
        .watch(quotationsRepositoryProvider)
        .getById(id);
  },
);

void invalidateQuotationState(WidgetRef ref, int? quotationId) {
  ref.invalidate(quotationsProvider);
  if (quotationId != null) {
    ref.invalidate(quotationProvider(quotationId));
  }
}
