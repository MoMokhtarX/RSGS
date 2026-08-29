import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import '../../../core/network/api_client.dart';
import '../models/report_models.dart';

class ReportsRepository {
  ReportsRepository(this._api);

  final ApiClient _api;

  Future<ReportSummary> getSummary({DateTime? from, DateTime? to}) async {
    final response = await _api.get(
      '/api/Reports/summary',
      queryParameters: {
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      },
    );

    if (response is Map) {
      return ReportSummary.fromJson(Map<String, dynamic>.from(response));
    }
    throw const FormatException('Invalid reports response.');
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(apiClientProvider)),
);

final reportsProvider = FutureProvider<ReportSummary>(
  (ref) { ref.watch(dataRefreshVersionProvider); return ref.watch(reportsRepositoryProvider).getSummary(); },
);
