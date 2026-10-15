// ============================================================
// dashboard_screen.dart (مع عداد إشعارات محدث لحظياً على زر التبويب)
// ============================================================
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../services/session_service.dart';
import '../services/notification_storage_service.dart';
import 'orders_tab_screen.dart';
import 'notifications_screen.dart';
import 'appearance_screen.dart';
import '../core/thems/app_colors.dart';
import '../core/thems/app_theme_notifier.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required List<String> allowedStatuses});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  String _sessionName = '';
  List<String> _allowedStatuses = [];
  bool _isLoading = true;
  bool _isSessionActive = true;
  int _currentIndex = 0;
  int _unreadCount = 0;
  Timer? _timer;
  StreamSubscription<DatabaseEvent>? _realtimeSubscription;

  late AnimationController _navController;
  double _startPosition = 0.0;
  double _targetPosition = 0.0;
  bool _isInitialized = false;
  double _dropFrequency = 2.0;
  double _stretchIntensity = 1.0;
  double _squashIntensity = 1.0;
  final Random _random = Random();
  final int _itemCount = 4;

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadSessionDataOfflineFirst();
    _updateFcmTokenOnServer();
    _loadUnreadCount();

    // تحديث عدد الإشعارات تلقائياً كل 3 ثوانٍ
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _realtimeSubscription?.cancel();
    _navController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      int unread = await NotificationStorageService.getUnreadCount();
      if (mounted && _unreadCount != unread) {
        setState(() {
          _unreadCount = unread;
        });
      }
    } catch (_) {}
  }

  Future<void> _updateFcmTokenOnServer() async {
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      String? accessToken = await SessionService.getToken();
      if (accessToken == null) return;

      final response = await http.post(
        Uri.parse('https://resonta-yalla-match-notifications.hf.space/auth/me/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );

      if (response.statusCode == 200) {
        debugPrint('FCM Token updated successfully on server.');
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  void _showDebugDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(message, style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSessionDataOfflineFirst() async {
    final name = await SessionService.getSessionName();
    final statuses = await SessionService.getAllowedStatuses();

    if (statuses.isEmpty) {
      _showDebugDialog(
        'تشخيص النظام: صلاحيات فارغة',
        'ملاحظة: تم جلب الصلاحيات محلياً ووجدت فارغة [].',
      );
    }

    if (mounted) {
      setState(() {
        _sessionName = name ?? 'معدّل';
        _allowedStatuses = statuses;
        _isLoading = false;
      });
    }
    _initFirebaseRealtimeListener();
  }

  Future<void> _initFirebaseRealtimeListener() async {
    final sessionId = await SessionService.getSessionId();
    if (sessionId == null || sessionId.isEmpty) return;

    final cleanSessionId = sessionId.trim();
    final ref = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://zubaida-beauty-default-rtdb.europe-west1.firebasedatabase.app',
    ).ref().child('editor_sessions/editors/$cleanSessionId');

    _realtimeSubscription = ref.onValue.listen((event) async {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        _handleSessionTermination('تم حذف جلستك من قِبل الإدارة');
        return;
      }

      final value = snapshot.value;
      if (value is! Map) return;

      final bool isActive = value['is_active'] ?? true;
      if (!isActive) {
        if (mounted) setState(() => _isSessionActive = false);
        return;
      }

      if (value['allowed_order_statuses'] != null) {
        final rawList = value['allowed_order_statuses'] as List;
        final List<String> updatedStatuses = rawList
            .whereType<String>()
            .toList();

        if (updatedStatuses.isNotEmpty) {
          final currentToken = await SessionService.getToken();

          await SessionService.saveSession(
            token: currentToken ?? '',
            sessionName: _sessionName,
            allowedStatuses: updatedStatuses,
            sessionId: cleanSessionId,
          );

          if (mounted) {
            setState(() {
              _allowedStatuses = updatedStatuses;
              _isSessionActive = true;
            });
          }
        }
      }
    });
  }

  Future<void> _handleSessionTermination(String message) async {
    _realtimeSubscription?.cancel();
    await SessionService.clearSession();
    if (mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/qr-scanner', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.primary),
      );
    }
  }

  Future<void> _logout() async {
    _realtimeSubscription?.cancel();
    await SessionService.clearSession();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/qr-scanner');
    }
  }

  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 'قيد المراجعة';
      case 'processing': return 'بحاجة لتجهيز';
      case 'shipping': return 'جاري الشحن';
      case 'completed': return 'مكتمل';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }

  void _onItemTapped(int index, double itemWidth, bool isRtl) {
    int oldCalculatedIndex = isRtl
        ? (_itemCount - 1 - _currentIndex)
        : _currentIndex;
    int newCalculatedIndex = isRtl ? (_itemCount - 1 - index) : index;

    setState(() {
      _startPosition = (oldCalculatedIndex + 0.5) * itemWidth;
      _targetPosition = (newCalculatedIndex + 0.5) * itemWidth;
      _currentIndex = index;

      _dropFrequency = 2.2 + (_random.nextDouble() * 2.0);
      _stretchIntensity = 1.3 + (_random.nextDouble() * 1.0);
      _squashIntensity = 0.9 + (_random.nextDouble() * 0.9);
    });

    // إذا انتقل المستخدم لتبويب الإشعارات، نقوم بتصفير العداد مؤقتاً
    if (index == 1) {
      setState(() {
        _unreadCount = 0;
      });
    } else {
      _loadUnreadCount();
    }

    if (oldCalculatedIndex == newCalculatedIndex) {
      _navController.duration = const Duration(milliseconds: 650);
      _navController.forward(from: 0.0);
    } else {
      double distance = (_targetPosition - _startPosition).abs();
      int dynamicDuration = (700 + (distance * 0.4)).clamp(800, 1200).toInt();
      _navController.duration = Duration(milliseconds: dynamicDuration);
      _navController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    final List<Widget> pages = [
      OrdersTabScreen(allowedStatuses: _allowedStatuses, orderId: '',),
      const NotificationsScreen(),
      const AppearanceScreen(),
      _buildSettingsView(),
    ];

    return AnimatedBuilder(
      animation: themeNotifier,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              Positioned.fill(
                bottom: 95,
                child: SafeArea(
                  bottom: false,
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : pages[_currentIndex],
                ),
              ),

              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double totalWidth = constraints.maxWidth;
                    double itemWidth = totalWidth / _itemCount;

                    if (!_isInitialized) {
                      int initialIndex = isRtl
                          ? (_itemCount - 1 - _currentIndex)
                          : _currentIndex;
                      _targetPosition = (initialIndex + 0.5) * itemWidth;
                      _startPosition = _targetPosition;
                      _isInitialized = true;
                    }

                    return Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          AnimatedBuilder(
                            animation: _navController,
                            builder: (context, child) {
                              double curvedValue = Curves
                                  .easeInOutCubicEmphasized
                                  .transform(_navController.value);
                              double currentX =
                                  ui.lerpDouble(
                                    _startPosition,
                                    _targetPosition,
                                    curvedValue,
                                  ) ??
                                  _targetPosition;

                              return Transform.translate(
                                offset: Offset(currentX - (itemWidth / 2), 0),
                                child: CustomPaint(
                                  size: Size(itemWidth, 70),
                                  painter: CleanGlassDropPainter(
                                    progress: _navController.value,
                                    isMoving: _navController.isAnimating,
                                    primaryColor: AppColors.primary,
                                    frequency: _dropFrequency,
                                    stretch: _stretchIntensity,
                                    squash: _squashIntensity,
                                  ),
                                ),
                              );
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildNavItem(
                                Icons.list_alt_rounded,
                                'الطلبات',
                                0,
                                itemWidth,
                                isRtl,
                              ),
                              _buildNavItem(
                                Icons.notifications_rounded,
                                'الإشعارات',
                                1,
                                itemWidth,
                                isRtl,
                                badgeCount: _unreadCount, // تمرير عداد الإشعارات هنا
                              ),
                              _buildNavItem(
                                Icons.palette_rounded,
                                'المظهر',
                                2,
                                itemWidth,
                                isRtl,
                              ),
                              _buildNavItem(
                                Icons.settings_rounded,
                                'الحساب',
                                3,
                                itemWidth,
                                isRtl,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              if (!_isSessionActive)
                Container(
                  color: Colors.black.withOpacity(0.85),
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_person_rounded,
                            color: AppColors.primary,
                            size: 80,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'تم إيقاف جلستك من قبل الإدارة',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _handleSessionTermination('تم إنهاء الجلسة'),
                            icon: const Icon(Icons.exit_to_app),
                            label: const Text('تسجيل الخروج'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    double itemWidth,
    bool isRtl, {
    int badgeCount = 0,
  }) {
    bool isSelected = _currentIndex == index;

    return Expanded(
      child: SizedBox.expand(
        child: GestureDetector(
          onTap: () => _onItemTapped(index, itemWidth, isRtl),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubicEmphasized,
              transform: Matrix4.translationValues(
                0,
                isSelected ? -3.0 : 0.0,
                0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: isSelected ? 26 : 22,
                      ),
                      if (badgeCount > 0)
                        Positioned(
                          right: -10,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                badgeCount > 9 ? '9+' : badgeCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: isSelected ? 11 : 10,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Zubaida-Beauty',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_rounded, size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  _sessionName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'متصل الآن',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حالات الطلبات المسموح بها',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allowedStatuses.map((status) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _translateStatus(status),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 35),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              label: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CleanGlassDropPainter extends CustomPainter {
  final double progress;
  final bool isMoving;
  final Color primaryColor;
  final double frequency;
  final double stretch;
  final double squash;

  CleanGlassDropPainter({
    required this.progress,
    required this.isMoving,
    required this.primaryColor,
    required this.frequency,
    required this.stretch,
    required this.squash,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    double decay = (1.0 - progress).clamp(0.0, 1.0);
    double wave = (isMoving && progress < 1.0)
        ? (sin(progress * pi * frequency) * decay)
        : 0.0;
    double absWave = wave.abs();

    double stretchX = absWave * (w * 0.22) * stretch;
    double squashY = absWave * 14.0 * squash;

    Path path = Path();

    double startX = 4.0 - stretchX;
    double endX = w - 4.0 + stretchX;
    double midX = (w / 2) + (wave * 2.5);

    path.moveTo(midX, 4.0 + squashY);

    path.cubicTo(
      endX * 0.85,
      4.0 + squashY,
      endX + 2,
      h * 0.4,
      endX - 2,
      h * 0.6,
    );

    path.cubicTo(
      endX - 2,
      h + (squashY * 0.4) - 2,
      endX * 0.6,
      h - 2.0,
      midX,
      h - 2.0,
    );

    path.cubicTo(
      endX * 0.4,
      h - 2.0,
      startX + 2,
      h + (squashY * 0.4) - 2,
      startX + 2,
      h * 0.6,
    );

    path.cubicTo(
      startX - 2,
      h * 0.4,
      startX * 0.15,
      4.0 + squashY,
      midX,
      4.0 + squashY,
    );
    path.close();

    canvas.drawShadow(path, Colors.black.withOpacity(0.18), 8.0, true);

    final Paint glassPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(midX, h * 0.35),
        w * 0.75,
        [
          primaryColor.withOpacity(0.32),
          primaryColor.withOpacity(0.10),
          Colors.white.withOpacity(0.15),
        ],
        [0.0, 0.65, 1.0],
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, glassPaint);

    final Paint borderPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(startX, 0),
        Offset(endX, h),
        [
          Colors.white.withOpacity(0.85),
          primaryColor.withOpacity(0.25),
          Colors.white.withOpacity(0.3),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CleanGlassDropPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isMoving != isMoving ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.frequency != frequency ||
        oldDelegate.stretch != stretch ||
        oldDelegate.squash != squash;
  }
}