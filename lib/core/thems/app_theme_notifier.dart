import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ThemeNotifier extends ChangeNotifier {
  int _currentThemeIndex = 0;
  List<Map<String, dynamic>> _customThemes = [];

  int get currentThemeIndex => _currentThemeIndex;
  List<Map<String, dynamic>> get customThemes => _customThemes;

  ThemeNotifier() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _currentThemeIndex = prefs.getInt('selected_theme_index') ?? 0;

    String? savedThemes = prefs.getString('custom_themes');
    if (savedThemes != null) {
      _customThemes = List<Map<String, dynamic>>.from(json.decode(savedThemes));
    }
    notifyListeners();
  }

  // الدالة الجديدة المحدثة لدعم إضافة سمة مخصصة بـ 4 ألوان كاملة
  Future<void> addCustomThemeWith4Colors(
    String name, 
    Color primary, 
    Color bg, 
    Color surface, 
    Color textPrimary
  ) async {
    _customThemes.add({
      'name': name,
      'primary': primary.value,
      'bg': bg.value,
      'surface': surface.value,
      'textPrimary': textPrimary.value,
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_themes', json.encode(_customThemes));

    // التبديل مباشرة للثيم الجديد المضاف (يبدأ الفهرس الخاص بالسمات المخصصة من 4)
    setThemeIndex(3 + _customThemes.length);
  }

  // حذف سمة مخصصة
  Future<void> deleteCustomTheme(int customIndex) async {
    _customThemes.removeAt(customIndex);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_themes', json.encode(_customThemes));

    if (_currentThemeIndex >= 4) {
      setThemeIndex(0);
    } else {
      notifyListeners();
    }
  }

  // تغيير الثيم لحظياً
  void setThemeIndex(int index) {
    _currentThemeIndex = index;
    SharedPreferences.getInstance().then((prefs) => prefs.setInt('selected_theme_index', index));
    notifyListeners(); // يُشغل التحديث اللحظي في التطبيق
  }
}

final themeNotifier = ThemeNotifier();