import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';
import '../../features/notifications/data/notifications_repository.dart';

class NotificationHelper {
  NotificationHelper(this._ref);
  final Ref _ref;

  static final provider = Provider<NotificationHelper>((ref) => NotificationHelper(ref));

  Future<void> showAndSave({
    required String title,
    required String body,
    String type = 'info',
  }) async {
    // 1. Show System Notification
    await _ref.read(notificationServiceProvider).showInstantNotification(
      title: title,
      body: body,
    );

    // 2. Save to API
    await _ref.read(notificationsRepositoryProvider).createNotification(
      title: title,
      message: body,
      type: type,
    );

    // 3. Invalidate Providers to update UI
    _ref.invalidate(notificationsStreamProvider);
    _ref.invalidate(unreadCountProvider);
  }
}
