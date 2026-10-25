// lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/theme/app_theme.dart';

/// Сервис выбора стилизации (4 варианта из дизайна SpeedVPS).
/// Применяет палитру к [AppColors] и уведомляет слушателей.
class ThemeService extends ChangeNotifier {
  static const String _variantKey = 'speedvps_theme_variant';

  final SharedPreferences _prefs;

  ThemeService(this._prefs) {
    AppColors.setVariant(variant);
  }

  AppThemeVariant get variant {
    final index = _prefs.getInt(_variantKey) ?? 0;
    return AppThemeVariant.values[index.clamp(
      0,
      AppThemeVariant.values.length - 1,
    )];
  }

  Future<void> setVariant(AppThemeVariant value) async {
    if (value == variant) return;
    await _prefs.setInt(_variantKey, value.index);
    AppColors.setVariant(value);
    notifyListeners();
  }
}
