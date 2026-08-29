import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';

import '../../../core/network/api_client.dart';
import '../../../core/models/app_models.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  List<NotificationModel> _parseList(dynamic response) {
    dynamic current = response;

    for (var depth = 0; depth < 4; depth++) {
      if (current is List) {
        return current
            .whereType<Map>()
            .map(
              (e) => NotificationModel.fromMap(
                Map<String, Object?>.from(e),
              ),
            )
            .toList();
      }

      if (current is Map) {
        if (current.containsKey('data')) {
          current = current['data'];
          continue;
        }

        if (current.containsKey('items')) {
          current = current['items'];
          continue;
        }

        if (current.containsKey('results')) {
          current = current['results'];
          continue;
        }
      }

      break;
    }

    return const <NotificationModel>[];
  }

  Future<List<NotificationModel>> getNotifications() async {
    final response = await _api.get('/api/Notifications');
    return _parseList(response);
  }

  Future<List<NotificationModel>> getUnreadNotifications() async {
    final response = await _api.get('/api/Notifications/unread');
    return _parseList(response);
  }

  Future<void> markRead(int id) async {
    await _api.patch('/api/Notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.patch('/api/Notifications/read-all');
  }

  Future<void> delete(int id) async {
    await _api.delete('/api/Notifications/$id');
  }

  Future<void> deleteAll() async {
    throw ApiException(
      405,
      'Clear all notifications is not supported by the current API.',
    );
  }

  Future<int> unreadCount() async {
    final notifications = await getUnreadNotifications();
    return notifications.length;
  }

  Future<void> createNotification({
    required String title,
    required String message,
    String type = 'info',
    DateTime? scheduledFor,
  }) async {
    await _api.post(
      '/api/Notifications',
      data: {
        'title': title,
        'message': message,
        'type': _notificationTypeValue(type),
        'scheduledFor': scheduledFor?.toUtc().toIso8601String(),
      },
    );
  }

  int _notificationTypeValue(String type) {
    switch (type.toLowerCase()) {
      case 'info':
        return 1;
      case 'success':
        return 2;
      case 'warning':
        return 3;
      case 'error':
        return 4;
      case 'followup':
      case 'follow_up':
        return 5;
      case 'reminder':
        return 6;
      default:
        return 99;
    }
  }
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(
    ref.watch(apiClientProvider),
  );
});

final notificationsStreamProvider =
    FutureProvider<List<NotificationModel>>((ref) {
  ref.watch(dataRefreshVersionProvider);
  return ref.watch(notificationsRepositoryProvider).getNotifications();
});

final unreadCountProvider = FutureProvider<int>((ref) {
  ref.watch(dataRefreshVersionProvider);
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});
