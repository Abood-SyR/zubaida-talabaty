// ============================================================
// notification_storage_service.dart (مع دالة جلب عدد الإشعارات غير المقروءة)
// ============================================================
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final String timestamp;
  bool isRead;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'timestamp': timestamp,
        'isRead': isRead,
      };

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) =>
      AppNotificationItem(
        id: json['id'],
        title: json['title'],
        body: json['body'],
        timestamp: json['timestamp'],
        isRead: json['isRead'] ?? false,
      );
}

class NotificationStorageService {
  static const String _key = 'local_notifications_list';

  static Future<List<AppNotificationItem>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return [];
    final List decoded = jsonDecode(data);
    return decoded.map((e) => AppNotificationItem.fromJson(e)).toList();
  }

  // دالة لجلب عدد الإشعارات غير المقروءة
  static Future<int> getUnreadCount() async {
    final list = await getNotifications();
    return list.where((item) => !item.isRead).length;
  }

  static Future<void> saveNotification(AppNotificationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getNotifications();
    // منع التكرار إذا كان الإشعار موجوداً مسبقاً بنفس الـ ID
    if (!list.any((element) => element.id == item.id)) {
      list.insert(0, item); // إضافة الحديث في الأعلى
      final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
      await prefs.setString(_key, encoded);
    }
  }

  static Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getNotifications();
    for (var item in list) {
      if (item.id == id) {
        item.isRead = true;
      }
    }
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  // دالة حذف إشعار محدد بالمعرّف
  static Future<void> deleteNotification(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getNotifications();
    list.removeWhere((item) => item.id == id);
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  // دالة مسح كافة الإشعارات
  static Future<void> clearAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}