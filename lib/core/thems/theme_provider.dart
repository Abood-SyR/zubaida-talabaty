import 'package:flutter/material.dart';
import 'package:light/light.dart';
import 'dart:async';

class ThemeManager with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isAutoSunModeEnabled = false;
  Light? _light;
  StreamSubscription? _subscription;

  ThemeMode get themeMode => _themeMode;
  bool get isAutoSunModeEnabled => _isAutoSunModeEnabled;

  // تبديل الوضع التلقائي بناءً على رغبة المستخدم من الإعدادات
  void toggleAutoSunMode(bool enabled) {
    _isAutoSunModeEnabled = enabled;
    if (enabled) {
      _startListeningToLightSensor();
    } else {
      _stopListeningToLightSensor();
      _themeMode = ThemeMode.dark; // العودة للوضع الافتراضي عند الإيقاف
    }
    notifyListeners();
  }

  void _startListeningToLightSensor() {
    try {
      _light = Light();
      _subscription = _light?.lightSensorStream.listen((int luxValue) {
        // إذا تجاوزت شدة الإضاءة 10,000 لوكس (ضوء شمس مباشر تقريباً)
        if (luxValue > 10000) {
          if (_themeMode != ThemeMode.light) {
            _themeMode = ThemeMode.light; // التبديل للمظهر الفاتح تلقائياً
            notifyListeners();
          }
        } else {
          // إذا انخفضت الإضاءة (ظل أو مكان مغلق أو الليل)
          if (_themeMode != ThemeMode.dark) {
            _themeMode = ThemeMode.dark; // العودة للمظهر الداكن تلقائياً
            notifyListeners();
          }
        }
      });
    } catch (_) {
      // في حال لم يكن الجهاز يحتوي على مستشعر إضاءة
    }
  }

  void _stopListeningToLightSensor() {
    _subscription?.cancel();
    _subscription = null;
  }
}