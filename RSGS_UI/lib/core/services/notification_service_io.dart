import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:audioplayers/audioplayers.dart';
import 'notification_service.dart';

NotificationService getNotificationService() => NotificationServiceIO();

class NotificationServiceIO implements NotificationService {
  final FlutterLocalNotificationsPlugin _mobileNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  Future<void> initialize() async {
    if (Platform.isWindows || Platform.isMacOS) {
      await localNotifier.setup(
        appName: 'Red Sea Green Solutions',
      );
    }
    
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin,
      );

      await _mobileNotificationsPlugin.initialize(
        initializationSettings,
      );
    }
  }

  @override
  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await _mobileNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS || Platform.isMacOS) {
      await _mobileNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      await _mobileNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  @override
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (Platform.isWindows || Platform.isMacOS) {
      LocalNotification notification = LocalNotification(
        title: title,
        body: body,
        silent: true,
      );
      
      try {
        await _audioPlayer.play(AssetSource('sounds/bell_notification.wav'));
      } catch (e) {
        notification = LocalNotification(
          title: title,
          body: body,
          silent: false,
        );
      }
      
      notification.show();
    }
    
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'event_channel_id',
        'Event Notifications',
        channelDescription: 'Notifications for calendar events',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('bell_notification'),
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: DarwinNotificationDetails(
          presentSound: true, 
          presentAlert: true, 
          presentBadge: true,
          sound: 'bell_notification.wav',
        ),
        macOS: DarwinNotificationDetails(
          presentSound: true, 
          presentAlert: true, 
          presentBadge: true,
          sound: 'bell_notification.wav',
        ),
      );

      await _mobileNotificationsPlugin.show(
        DateTime.now().millisecond,
        title,
        body,
        platformChannelSpecifics,
      );
    }
  }
}
