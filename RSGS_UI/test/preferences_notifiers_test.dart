import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsgs/core/localization/language_provider.dart';
import 'package:rsgs/core/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('locale notifier persists explicit selection and toggles language', () async {
    final notifier = LocaleNotifier();
    await notifier.setLocale(const Locale('ar'));
    expect(notifier.state.languageCode, 'ar');
    expect(notifier.isArabic, isTrue);
    notifier.toggleLocale();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.languageCode, 'en');
    expect((await SharedPreferences.getInstance()).getString('app_locale'), 'en');
  });

  test('theme notifier persists selection and toggles between light and dark', () async {
    final notifier = ThemeModeNotifier();
    await notifier.setThemeMode(ThemeMode.light);
    notifier.toggleTheme();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state, ThemeMode.dark);
    expect((await SharedPreferences.getInstance()).getInt('selected_theme_mode'), ThemeMode.dark.index);
  });
}
