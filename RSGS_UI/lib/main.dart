import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'features/auth/data/auth_repository.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeDateFormatting('ar', null);
  await initializeDateFormatting('en', null);

  await NotificationService().initialize();
  await NotificationService().requestPermissions();

  try {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1300, 850),
      minimumSize: Size(360, 600),
      center: true,
      title: 'Red Sea Green Solutions',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e) {
    debugPrint('Window manager error: $e');
  }

  final container = ProviderContainer();

  await container.read(authProvider.notifier).restoreSession();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RedSeaApp(),
    ),
  );
}