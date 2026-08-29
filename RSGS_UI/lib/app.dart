import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/localization/language_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class RedSeaApp extends ConsumerWidget {
  const RedSeaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp.router(
      title: 'Red Sea Green Solutions',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(locale.languageCode),
      darkTheme: AppTheme.dark(locale.languageCode),
      themeMode: themeMode,
      routerConfig: router,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        if (child == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return ResponsiveBreakpoints.builder(
          child: child,
          breakpoints: const [
            Breakpoint(start: 0, end: 600, name: MOBILE),
            Breakpoint(start: 601, end: 1250, name: TABLET),
            Breakpoint(start: 1251, end: double.infinity, name: DESKTOP),
          ],
        );
      },
    );
  }
}
