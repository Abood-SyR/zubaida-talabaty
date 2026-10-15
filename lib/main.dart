// ============================================================
// main.dart (النسخة الكاملة والمصححة للويب والهواتف)
// ============================================================
// ignore_for_file: unused_element

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:talabaty/firebase_options.dart';
import 'package:light/light.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'services/notification_service.dart';
import 'services/session_service.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/dashboard_screen.dart';
import 'core/thems/app_colors.dart';
import 'core/thems/app_theme_notifier.dart';

Light? _globalLight;
StreamSubscription? _globalLightSubscription;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (!kIsWeb) {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  }

  await NotificationService.initialize();
  _initGlobalAutoSunMode();

  final String? token = await SessionService.getToken();
  final bool isLoggedIn = token != null && token.isNotEmpty;
  final String initialRoute = isLoggedIn ? '/dashboard' : '/qr-scanner';

  runApp(TalabatyApp(initialRoute: initialRoute));
}

void _initGlobalAutoSunMode() {
  // حساس الإضاءة غير مدعوم على الويب، لذا نتخطاه لمنع الانهيار على Safari
  if (kIsWeb) return;

  SharedPreferences.getInstance().then((prefs) {
    bool isAutoEnabled = prefs.getBool('auto_sun_mode') ?? false;
    if (isAutoEnabled) {
      try {
        _globalLight = Light();
        _globalLightSubscription = _globalLight?.lightSensorStream.listen((int luxValue) {
          int dayIndex = prefs.getInt('auto_day_theme_index') ?? 1;
          int nightIndex = prefs.getInt('auto_night_theme_index') ?? 0;

          if (luxValue > 10000) {
            if (themeNotifier.currentThemeIndex != dayIndex) {
              themeNotifier.setThemeIndex(dayIndex);
            }
          } else {
            if (themeNotifier.currentThemeIndex != nightIndex) {
              themeNotifier.setThemeIndex(nightIndex);
            }
          }
        });
      } catch (_) {}
    }
  });
}

class TalabatyApp extends StatelessWidget {
  final String initialRoute;
  final String apiBaseUrl = 'https://resonta-yalla-match-notifications.hf.space';

  const TalabatyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zubaida-Beauty Admin/Editor',
      debugShowCheckedModeBanner: false,
      // ربط مفتاح التنقل العالمي هنا لتمكين الانتقال المباشر من الإشعارات
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      routes: {
        '/qr-scanner': (context) => QRScannerScreen(baseUrl: apiBaseUrl),
        '/dashboard': (context) => const DashboardScreen(allowedStatuses: []),
      },
    );
  }
}