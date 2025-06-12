import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier {
  static final ValueNotifier<ThemeMode> theme =
      ValueNotifier(ThemeMode.light);

  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool('dark_theme') ?? false;
    theme.value = dark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setDark(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_theme', dark);
    theme.value = dark ? ThemeMode.dark : ThemeMode.light;
  }
}
