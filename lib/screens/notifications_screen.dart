// ============================================================
// notifications_screen.dart (الانتقال المباشر لصفحة تفاصيل الطلب عبر جلب بياناته)
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:talabaty/screens/order_details_screen.dart';
import 'package:talabaty/services/session_service.dart';
import '../services/notification_storage_service.dart';
// import '../services/notification_service.dart';
import '../../core/thems/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  final String? initialSelectedNotificationId;

  const NotificationsScreen({
    super.key,
    this.initialSelectedNotificationId,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<AppNotificationItem> _notifications = [];
  bool _isLoading = true;
  
  final Set<String> _selectedIds = {};
  final Set<String> _viewedIdsDuringSession = {};
  final List<String> _filterKeys = ['all', 'unread', 'today'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filterKeys.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    if (widget.initialSelectedNotificationId != null) {
      _selectedIds.add(widget.initialSelectedNotificationId!);
    }

    _loadNotifications();
  }

  @override
  void dispose() {
    _markViewedAsReadOnExit();
    _tabController.dispose();
    super.dispose();
  }

  String _translateFilter(String filterKey) {
    switch (filterKey) {
      case 'all': return 'الكل';
      case 'unread': return 'غير المقروءة';
      case 'today': return 'اليوم';
      default: return filterKey;
    }
  }

  Future<void> _loadNotifications() async {
    final items = await NotificationStorageService.getNotifications();

    if (mounted) {
      setState(() {
        _notifications = items;
        _isLoading = false;
      });

      for (var item in items) {
        _viewedIdsDuringSession.add(item.id);
      }
    }
  }

  Future<void> _markViewedAsReadOnExit() async {
    for (var id in _viewedIdsDuringSession) {
      final index = _notifications.indexWhere((element) => element.id == id);
      if (index != -1 && !_notifications[index].isRead) {
        await NotificationStorageService.markAsRead(id);
      }
    }
  }

  List<AppNotificationItem> get _filteredNotifications {
    final now = DateTime.now();
    final currentFilter = _filterKeys[_tabController.index];

    return _notifications.where((item) {
      if (currentFilter == 'unread') {
        return !item.isRead;
      } else if (currentFilter == 'today') {
        final dayStr = now.day.toString().padLeft(2, '0');
        return item.timestamp.contains(dayStr);
      }
      return true;
    }).toList();
  }

  Future<void> _deleteSelected() async {
    for (var id in _selectedIds) {
      await NotificationStorageService.deleteNotification(id);
    }
    setState(() {
      _selectedIds.clear();
    });
    _loadNotifications();
  }

  void _toggleSelectAll(List<AppNotificationItem> displayList) {
    setState(() {
      if (_selectedIds.length == displayList.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
        _selectedIds.addAll(displayList.map((e) => e.id));
      }
    });
  }

  Future<void> _markSelectedAsRead() async {
    for (var id in _selectedIds) {
      await NotificationStorageService.markAsRead(id);
    }
    setState(() {
      _selectedIds.clear();
    });
    _loadNotifications();
  }

  // دالة جلب بيانات الطلب مباشرة من السيرفر والانتقال إلى صفحة تفاصيل الطلب
  Future<void> _navigateToOrderDetails(AppNotificationItem item) async {
    // استخدام الـ id الخاص بالإشعار والذي يمثل معرّف الطلب (order_id)
    final String orderId = item.id;

    // إظهار مؤشر تحميل خفيف أثناء الاتصال بالسيرفر
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final Dio dio = await SessionService.getDioClient();
      final response = await dio.get('/orders/$orderId');

      if (Navigator.canPop(context)) Navigator.of(context).pop(); // إغلاق مؤشر التحميل

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> orderData = response.data;
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailsScreen(orderData: orderData),
            ),
          );
        }
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.of(context).pop(); // إغلاق مؤشر التحميل
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر جلب تفاصيل الطلب من السيرفر، تأكد من الاتصال والصلاحيات'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredNotifications;
    final bool isAllSelected = displayList.isNotEmpty && _selectedIds.length == displayList.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.background,
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: AppColors.surface,
                      unselectedLabelColor: AppColors.textSecondary,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: AppColors.primary,
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      unselectedLabelStyle: const TextStyle(fontSize: 13),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                      tabs: _filterKeys.map((key) => Tab(text: _translateFilter(key))).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedIds.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.done_all_rounded, size: 20),
                          color: AppColors.textPrimary,
                          tooltip: 'تمييز كمقروء',
                          onPressed: _markSelectedAsRead,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          color: Colors.redAccent,
                          tooltip: 'حذف المحدد',
                          onPressed: _deleteSelected,
                        ),
                        IconButton(
                          icon: Icon(
                            isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                            size: 20,
                          ),
                          color: AppColors.textPrimary,
                          tooltip: isAllSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل',
                          onPressed: () => _toggleSelectAll(displayList),
                        ),
                      ] else if (_notifications.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.select_all_rounded, size: 20),
                          color: AppColors.textPrimary,
                          tooltip: 'تحديد الكل',
                          onPressed: () => _toggleSelectAll(displayList),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : displayList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_none_rounded,
                                size: 56,
                                color: AppColors.textSecondary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد إشعارات مسجلة',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            final item = displayList[index];
                            final isSelected = _selectedIds.contains(item.id);
                            final bool isTargetIncoming = widget.initialSelectedNotificationId == item.id;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? AppColors.primary.withOpacity(0.12) 
                                    : (item.isRead ? AppColors.surface : AppColors.primary.withOpacity(0.05)),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected || isTargetIncoming
                                      ? AppColors.primary 
                                      : AppColors.textSecondary.withOpacity(0.08),
                                  width: isTargetIncoming ? 1.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isTargetIncoming 
                                        ? AppColors.primary.withOpacity(0.15) 
                                        : Colors.black.withOpacity(0.03),
                                    blurRadius: isTargetIncoming ? 12 : 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Checkbox(
                                  value: isSelected,
                                  activeColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedIds.add(item.id);
                                      } else {
                                        _selectedIds.remove(item.id);
                                      }
                                    });
                                  },
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (!item.isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      item.body,
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 12,
                                          color: AppColors.textSecondary.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item.timestamp,
                                          style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                // عند النقر على محتوى الإشعار يتم جلب تفاصيل الطلب والانتقال لها مباشرة
                                onTap: () {
                                  _navigateToOrderDetails(item);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}