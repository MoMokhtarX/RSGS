import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_io.dart';

abstract class NotificationService {
  factory NotificationService() => getNotificationService();
  
  Future<void> initialize();
  Future<void> requestPermissions();
  Future<void> showInstantNotification({required String title, required String body});
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
