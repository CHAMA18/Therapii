import 'package:flutter/material.dart';

/// Global controller for handling theme mode changes across the app.
class ThemeModeController extends ChangeNotifier {
  ThemeModeController();

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggleLightDark() {
    setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

final ThemeModeController themeModeController = ThemeModeController();