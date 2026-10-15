// ============================================================
// main_navigation.dart (مع عداد إشعارات محدث لحظياً وتلقائياً)
// ============================================================
import 'dart:ui' as ui;
import 'dart:math';
import 'dart:async'; // استيراد المؤقت
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/thems/app_colors.dart';
import '../core/thems/app_theme_notifier.dart';
import 'orders_tab_screen.dart';
import 'notifications_screen.dart';
import 'appearance_screen.dart';
import '../services/notification_storage_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _controller;
  Timer? _timer; // مؤقت لتحديث العداد في الخلفية
  
  double _startPosition = 0.0;
  double _targetPosition = 0.0;
  bool _isInitialized = false;
  
  double _dropFrequency = 2.0;
  double _stretchIntensity = 1.0;
  double _squashIntensity = 1.0;
  final Random _random = Random();
  
  int _unreadCount = 0;
  final int _itemCount = 4;

  final List<Widget> _screens = [
    const OrdersTabScreen(allowedStatuses: ['pending', 'processing', 'shipping', 'completed'], orderId: '',),
    const NotificationsScreen(),
    const AppearanceScreen(),
    const Center(child: Text('صفحة الحساب والإعدادات')),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadUnreadCount();

    // التحقق من العداد وتحديثه تلقائياً كل 3 ثوانٍ لضمان ظهوره فوراً
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // إلغاء المؤقت عند إغلاق الشاشة
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final notifications = await NotificationStorageService.getNotifications();
      int unread = notifications.where((item) => !item.isRead).length;
      if (mounted && _unreadCount != unread) {
        setState(() {
          _unreadCount = unread;
        });
      }
    } catch (_) {}
  }

  void _onItemTapped(int index, double itemWidth, bool isRtl) {
    int oldCalculatedIndex = isRtl ? (_itemCount - 1 - _currentIndex) : _currentIndex;
    int newCalculatedIndex = isRtl ? (_itemCount - 1 - index) : index;

    setState(() {
      _startPosition = (oldCalculatedIndex + 0.5) * itemWidth;
      _targetPosition = (newCalculatedIndex + 0.5) * itemWidth;
      _currentIndex = index;

      _dropFrequency = 2.2 + (_random.nextDouble() * 2.0);
      _stretchIntensity = 1.3 + (_random.nextDouble() * 1.0);
      _squashIntensity = 0.9 + (_random.nextDouble() * 0.9);
    });

    if (index == 1) {
      setState(() {
        _unreadCount = 0;
      });
    } else {
      _loadUnreadCount();
    }

    if (oldCalculatedIndex == newCalculatedIndex) {
      _controller.duration = const Duration(milliseconds: 650);
      _controller.forward(from: 0.0);
    } else {
      double distance = (_targetPosition - _startPosition).abs();
      int dynamicDuration = (700 + (distance * 0.4)).clamp(800, 1200).toInt();
      _controller.duration = Duration(milliseconds: dynamicDuration);
      _controller.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRtl = context.locale.languageCode == 'ar';

    return AnimatedBuilder(
      animation: themeNotifier,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 25,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double totalWidth = constraints.maxWidth;
                    double itemWidth = totalWidth / _itemCount;
                    
                    if (!_isInitialized) {
                      int initialIndex = isRtl ? (_itemCount - 1 - _currentIndex) : _currentIndex;
                      _targetPosition = (initialIndex + 0.5) * itemWidth;
                      _startPosition = _targetPosition;
                      _isInitialized = true;
                    }

                    return Container(
                      height: 75,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                      ),
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              double curvedValue = Curves.easeInOutCubicEmphasized.transform(_controller.value);
                              double currentX = ui.lerpDouble(_startPosition, _targetPosition, curvedValue) ?? _targetPosition;

                              return Transform.translate(
                                offset: Offset(currentX - (itemWidth / 2), 0),
                                child: CustomPaint(
                                  size: Size(itemWidth, 75),
                                  painter: CleanGlassDropPainter(
                                    progress: _controller.value,
                                    isMoving: _controller.isAnimating,
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
                              _buildNavItem(Icons.list_alt_rounded, 'الطلبات', 0, itemWidth, isRtl),
                              _buildNavItem(Icons.notifications_rounded, 'الإشعارات', 1, itemWidth, isRtl, badgeCount: _unreadCount),
                              _buildNavItem(Icons.palette_rounded, 'المظهر', 2, itemWidth, isRtl),
                              _buildNavItem(Icons.settings_rounded, 'الحساب', 3, itemWidth, isRtl),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, double itemWidth, bool isRtl, {int badgeCount = 0}) {
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
              transform: Matrix4.translationValues(0, isSelected ? -4.0 : 0.0, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
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
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontSize: isSelected ? 11 : 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
}

// 💧 رسام القطرة الزجاجية المتناسق
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
    double wave = (isMoving && progress < 1.0) ? (sin(progress * pi * frequency) * decay) : 0.0;
    double absWave = wave.abs();

    double stretchX = absWave * (w * 0.22) * stretch; 
    double squashY = absWave * 14.0 * squash; 

    Path path = Path();
    
    double startX = 4.0 - stretchX;
    double endX = w - 4.0 + stretchX;
    double midX = (w / 2) + (wave * 2.5);

    path.moveTo(midX, 4.0 + squashY); 
    
    path.cubicTo(
      endX * 0.85, 4.0 + squashY, 
      endX + 2, h * 0.4, 
      endX - 2, h * 0.6
    );
    
    path.cubicTo(
      endX - 2, h + (squashY * 0.4) - 2, 
      endX * 0.6, h - 2.0, 
      midX, h - 2.0
    );

    path.cubicTo(
      endX * 0.4, h - 2.0, 
      startX + 2, h + (squashY * 0.4) - 2, 
      startX + 2, h * 0.6
    );

    path.cubicTo(
      startX - 2, h * 0.4, 
      startX * 0.15, 4.0 + squashY, 
      midX, 4.0 + squashY
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