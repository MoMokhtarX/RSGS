import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/app_models.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(apiClientProvider));
});

class ActivityRepository {
  ActivityRepository(this._api);

  final ApiClient _api;

  Future<void> logActivity({
    String? action,
    String? details,
    String? entityType,
    int? entityId,
    int? userId,
    String? userName,
  }) async {}

  Future<List<ActivityModel>> getActivities([int? userId]) async {
    try {
      final response = await _api.get(
        '/api/ActivityLogs',
        queryParameters: {
          'pageNumber': 1,
          'pageSize': 100,
          'userId': userId,
        },
      );

      dynamic data = response;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        data = map['items'] ?? map['data'];
      }

      if (data is! List) return [];

      return data
          .whereType<Map>()
          .map(
            (e) => ActivityModel.fromMap(
              Map<String, Object?>.from(e),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }
}
