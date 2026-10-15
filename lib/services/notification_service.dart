// ============================================================
// notification_service.dart (النسخة الكاملة والمصححة للويب والهواتف)
// ============================================================
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:talabaty/screens/order_details_screen.dart';
import 'package:talabaty/screens/orders_tab_screen.dart';
import 'session_service.dart';
import 'notification_storage_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'إشعارات الطلبات المهمة',
    description: 'تستخدم هذه القناة للإشعارات الفورية للطلبات الجديدة وتحديثاتها.',
    importance: Importance.max,
    playSound: true,
  );

  static final Set<String> _processedMessageIds = {};
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // على الويب، لا ندعم تهيئة إشعارات الأندرويد المحلية لتجنب الانهيار على Safari
    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationClick(response.payload);
        },
      );

      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    } else {
      // تهيئة بسيطة للويب إن وجدت أو تخطي
      const InitializationSettings initializationSettings =
          InitializationSettings();
      await _localNotificationsPlugin.initialize(initializationSettings);
    }

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final String? orderId = message.data['order_id']?.toString() ?? message.data['id']?.toString();
      final String msgId = orderId ?? message.messageId ?? 'general_${DateTime.now().millisecondsSinceEpoch}';
      _handleNotificationClick(msgId);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final String? orderId = message.data['order_id']?.toString() ?? message.data['id']?.toString();
      final String msgId = orderId ?? message.messageId ?? 'order_general_${DateTime.now().millisecondsSinceEpoch}';

      if (_processedMessageIds.contains(msgId)) return;
      _processedMessageIds.add(msgId);
      Future.delayed(const Duration(minutes: 1), () => _processedMessageIds.remove(msgId));

      final String eventType = message.data['event_type'] ?? '';
      final String orderStatus = message.data['new_status'] ?? message.data['status'] ?? '';
      
      final List<String> allowedStatuses = await SessionService.getAllowedStatuses();
      if (orderStatus.isNotEmpty && allowedStatuses.isNotEmpty && !allowedStatuses.contains(orderStatus)) {
        return; 
      }

      String title = 'تحديث جديد';
      String body = 'لديك تحديث جديد في الطلبات';

      if (eventType == 'new_order') {
        final amount = message.data['total_amount'] ?? '0';
        final customer = message.data['customer_name'] ?? 'زائر';
        title = 'طلب جديد';
        body = 'طلب جديد بقيمة $amount ل.س من العميل: $customer';
      } else if (eventType == 'status_change') {
        final newStatus = message.data['new_status'] ?? '';
        title = 'تحديث حالة طلب';
        body = 'تم تغيير حالة الطلب إلى: $newStatus';
      } else {
        title = message.data['title'] ?? 'إشعار إداري';
        body = message.data['body'] ?? 'يوجد تحديث جديد في النظام.';
      }

      final now = DateTime.now();
      final int hour24 = now.hour;
      final int hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
      final String period = hour24 >= 12 ? 'مساءً' : 'صباحاً';
      final String minuteStr = now.minute.toString().padLeft(2, '0');
      
      final String formattedTimestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} | $hour12:$minuteStr $period';

      await NotificationStorageService.saveNotification(
        AppNotificationItem(
          id: msgId,
          title: title,
          body: body,
          timestamp: formattedTimestamp,
          isRead: false,
        ),
      );

      // إظهار الإشعار المحلي فقط على الأنظمة المدعومة (غير الويب)
      if (!kIsWeb) {
        _localNotificationsPlugin.show(
          msgId.hashCode,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: msgId,
        );
      }
    }); 
  }

  static void _handleNotificationClick(String? notificationId) async {
    if (navigatorKey.currentState != null && notificationId != null) {
      try {
        final Dio dio = await SessionService.getDioClient();
        final response = await dio.get('/orders/$notificationId');

        if (response.statusCode == 200 && response.data != null) {
          final Map<String, dynamic> orderData = response.data;
          
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (context) => OrderDetailsScreen(orderData: orderData),
            ),
          );
        }
      } catch (e) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => OrdersTabScreen(
              allowedStatuses: const ['pending', 'processing', 'shipping', 'completed'],
              initialSelectedOrderId: notificationId, orderId: '',
            ),
          ),
        );
      }
    }
  }
}