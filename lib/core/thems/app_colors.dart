import 'package:flutter/material.dart';
import 'app_theme_notifier.dart';

class AppColors {
  // الثيمات الثابتة
  static const Color pinkPrimary = Color(0xFFE91E63);
  static const Color pinkBackground = Color(0xFFFDF0F5);
  static const Color pinkSurface = Color(0xFFF8BBD0);

  static const Color greenPrimary = Color(0xFF4CAF50);
  static const Color greenBackground = Color(0xFFF1F8E9);
  static const Color greenSurface = Color(0xFFC8E6C9);

  // اللون الأساسي
  static Color get primary {
    int index = themeNotifier.currentThemeIndex;
    if (index >= 4) {
      int customIdx = index - 4;
      if (customIdx < themeNotifier.customThemes.length) {
        var theme = themeNotifier.customThemes[customIdx];
        if (theme['primary'] != null) return Color(theme['primary']);
      }
    }
    switch (index) {
      case 1: return Colors.blueAccent;
      case 2: return pinkPrimary;
      case 3: return greenPrimary;
      default: return Colors.deepPurpleAccent;
    }
  }

  // خلفية الشاشة
  static Color get background {
    int index = themeNotifier.currentThemeIndex;
    if (index >= 4) {
      int customIdx = index - 4;
      if (customIdx < themeNotifier.customThemes.length) {
        var theme = themeNotifier.customThemes[customIdx];
        if (theme['bg'] != null) return Color(theme['bg']);
      }
    }
    switch (index) {
      case 1: return const Color(0xFFF5F5F7);
      case 2: return pinkBackground;
      case 3: return greenBackground;
      default: return const Color(0xFF121212);
    }
  }

  // لون الكروت والأسطح (Surface)
  static Color get surface {
    int index = themeNotifier.currentThemeIndex;
    if (index >= 4) {
      int customIdx = index - 4;
      if (customIdx < themeNotifier.customThemes.length) {
        var theme = themeNotifier.customThemes[customIdx];
        if (theme['surface'] != null) return Color(theme['surface']);
      }
    }
    switch (index) {
      case 1: return Colors.white;
      case 2: return pinkSurface;
      case 3: return greenSurface;
      default: return const Color(0xFF1E1E1E);
    }
  }

  // النص الأساسي
  static Color get textPrimary {
    int index = themeNotifier.currentThemeIndex;
    if (index >= 4) {
      int customIdx = index - 4;
      if (customIdx < themeNotifier.customThemes.length) {
        var theme = themeNotifier.customThemes[customIdx];
        if (theme['textPrimary'] != null) return Color(theme['textPrimary']);
      }
    }
    return (index == 1 || index == 2 || index == 3) ? Colors.black87 : Colors.white;
  }

  // النص الثانوي
  static Color get textSecondary {
    int index = themeNotifier.currentThemeIndex;
    if (index >= 4) {
      int customIdx = index - 4;
      if (customIdx < themeNotifier.customThemes.length) {
        var theme = themeNotifier.customThemes[customIdx];
        if (theme['textPrimary'] != null) {
          return Color(theme['textPrimary']).withOpacity(0.7);
        }
      }
    }
    return (index == 1 || index == 2 || index == 3) ? Colors.black54 : Colors.grey;
  }
}

