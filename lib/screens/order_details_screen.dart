// ============================================================
// order_details_screen.dart (مع دعم الاتصال المباشر وزر نسخ رقم الهاتف)
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:talabaty/screens/product_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';
import '../../core/thems/app_colors.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const OrderDetailsScreen({super.key, required this.orderData});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Map<String, dynamic> _currentOrder;
  bool _isUpdating = false;
  bool _isCompletedFullScreen = false;

  final Map<String, String> _fetchedItemNames = {};
  final Map<String, bool> _loadingItems = {};
  final Set<String> _checkedKeys = {};

  double _dragExtent = 0.0;
  final double _maxDrag = 250.0;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.orderData;
    _fetchMissingItemNames();
  }

  void _fetchMissingItemNames() async {
    final items = (_currentOrder['items'] as List?) ??
        (_currentOrder['items_details'] as List?) ??
        (_currentOrder['order_items'] as List?) ??
        [];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final rawName = item['product_name'] ?? item['product']?['name'] ?? item['title'];
      final itemType = item['item_type'] ?? 'product';
      final sourceId = (item['source_id'] ?? item['product_id'] ?? item['product']?['id'])?.toString();

      if ((rawName == null || rawName.toString().isEmpty) && sourceId != null) {
        if (!_fetchedItemNames.containsKey(sourceId) && !(_loadingItems[sourceId] ?? false)) {
          setState(() {
            _loadingItems[sourceId] = true;
          });
          try {
            final Dio dio = await SessionService.getDioClient();

            String endpoint = '/products/$sourceId';
            if (itemType == 'offer') {
              endpoint = '/offers/$sourceId';
            } else if (itemType == 'group') {
              endpoint = '/product-groups/$sourceId';
            }

            Response response = await dio.get(endpoint);
            if (response.statusCode == 200 && response.data != null) {
              final data = response.data;
              String name = 'عنصر #$sourceId';
              if (data is Map) {
                final n = data['name'] ?? data['title'];
                if (n is String) {
                  name = n;
                } else if (n is Map) {
                  name = n['ar'] ?? n['en'] ?? n.values.first.toString();
                }
              }
              setState(() {
                _fetchedItemNames[sourceId] = name;
                _loadingItems[sourceId] = false;
              });
            }
          } catch (e) {
            setState(() {
              _loadingItems[sourceId] = false;
            });
          }
        }
      }
    }
  }

  // دالة لإجراء مكالمة هاتفية مباشرة
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إجراء المكالمة بهذا الرقم'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // دالة لنسخ رقم الهاتف إلى الحافظة
  void _copyPhoneNumber(String phoneNumber) {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ رقم الهاتف إلى الحافظة'), backgroundColor: Colors.green),
    );
  }

  void _showCancelConfirmationDialog() {
    final TextEditingController textController = TextEditingController();
    const requiredText = "انا مسؤول عن الغاء الطلب";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('تأكيد إلغاء الطلب',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'لتأكيد عملية إلغاء الطلب وإرجاع الكميات للمخزون، يرجى كتابة النص التالي بدقة:',
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const SelectableText(
                  requiredText,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      fontSize: 13),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'اكتب النص هنا...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('تراجع', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                if (textController.text.trim() == requiredText) {
                  Navigator.of(context).pop();
                  _updateOrderStatus('cancelled');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('النص المدخل غير مطابق، يرجى كتابته بدقة'),
                        backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('تأكيد الإلغاء', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final Dio dio = await SessionService.getDioClient();

      final orderId = _currentOrder['order_id'] ?? _currentOrder['id'];
      Response response = await dio.patch(
        '/orders/$orderId/status',
        queryParameters: {'new_status': newStatus},
      );

      if (response.statusCode == 200) {
        setState(() {
          _currentOrder['status'] = newStatus;
          _isUpdating = false;
          _isCompletedFullScreen = true;
        });
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('فشل تحديث حالة الطلب، تأكد من الاتصال'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _openProofUrl(String proofUrl) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final Dio dio = await SessionService.getDioClient();

      Response<List<int>> response = await dio.get<List<int>>(
        proofUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (Navigator.canPop(context)) Navigator.of(context).pop();

      if (response.statusCode == 200 && response.data != null) {
        final bytes = response.data!;
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxHeight: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('إثبات التحويل المالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        child: Image.memory(
                          UriData.fromBytes(bytes).contentAsBytes(),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                'تم استلام ملف PDF أو مستند إثبات التحويل بنجاح.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تحميل إثبات التحويل، تأكد من الصلاحيات والاتصال'), backgroundColor: Colors.red),
      );
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'pending': return 'قيد المراجعة';
      case 'processing': return 'بحاجة لتجهيز';
      case 'shipping': return 'جاري الشحن';
      case 'completed': return 'مكتمل';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orangeAccent;
      case 'processing': return AppColors.primary;
      case 'shipping': return Colors.purpleAccent;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.redAccent;
      default: return AppColors.textSecondary;
    }
  }

  List<Map<String, dynamic>> _groupOrderItems(List<dynamic> rawItems) {
    final Map<String, List<dynamic>> groupedMap = {};
    final List<Map<String, dynamic>> finalResult = [];

    for (var item in rawItems) {
      final itemType = item['item_type'] ?? 'product';
      final sourceId = item['source_id']?.toString() ?? item['product_id']?.toString() ?? '';

      if (itemType == 'offer' || itemType == 'group') {
        if (!groupedMap.containsKey(sourceId)) {
          groupedMap[sourceId] = [];
        }
        groupedMap[sourceId]!.add(item);
      } else {
        finalResult.add({
          'isGrouped': false,
          'item_type': itemType,
          'item': item,
        });
      }
    }

    groupedMap.forEach((sourceId, groupItems) {
      final firstItem = groupItems.first;
      final itemType = firstItem['item_type'];
      final parentName = itemType == 'offer' ? 'عرض خاص (حزمة)' : 'مجموعة منتجات';

      finalResult.add({
        'isGrouped': true,
        'source_id': sourceId,
        'item_type': itemType,
        'parent_name': parentName,
        'sub_items': groupItems,
      });
    });

    return finalResult;
  }

  String _extractName(dynamic rawName, String fallback) {
    if (rawName is String && rawName.isNotEmpty) return rawName;
    if (rawName is Map) {
      return rawName['ar'] ?? rawName['en'] ?? (rawName.values.isNotEmpty ? rawName.values.first.toString() : fallback);
    }
    return fallback;
  }

  Widget _buildDragToConfirmSlider({
    required String text,
    required String targetStatus,
    required Color activeColor,
  }) {
    return Column(
      children: [
        Text(
          'اسحب السهم من اليمين لليسار للتأكيد',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            color: activeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              Center(
                child: Text(
                  text,
                  style: TextStyle(
                      color: activeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              Positioned(
                left: _dragExtent,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragExtent += details.delta.dx;
                      if (_dragExtent < 0) _dragExtent = 0;
                      if (_dragExtent > _maxDrag) _dragExtent = _maxDrag;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_dragExtent >= _maxDrag * 0.8) {
                      _dragExtent = 0.0;
                      _updateOrderStatus(targetStatus);
                    } else {
                      setState(() {
                        _dragExtent = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeColor,
                    ),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCompletedFullScreen) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.green, size: 60),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'تم تأكيد العملية بنجاح!',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('العودة للطلبات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final orderId = (_currentOrder['order_id'] ?? _currentOrder['id'] ?? '').toString();
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    final status = _currentOrder['status'] ?? 'pending';

    final addressData = _currentOrder['shipping_address'];
    String addressText = 'غير متوفر';
    String customerName = _currentOrder['customer_name'] ?? 'غير محدد';
    String customerPhone = '-';
    Map<String, dynamic>? coordinates;

    if (addressData is Map) {
      addressText = addressData['address_text'] ?? addressData['address'] ?? addressData.toString();
      customerName = addressData['name'] ?? customerName;
      customerPhone = addressData['phone'] ?? '-';
      coordinates = addressData['coordinates'];
    }

    final rawItems = (_currentOrder['items'] as List?) ??
        (_currentOrder['items_details'] as List?) ??
        (_currentOrder['order_items'] as List?) ??
        [];

    final groupedItems = _groupOrderItems(rawItems);

    final String rawPaymentStatus = _currentOrder['payment_status'] ?? 'unpaid';
    final bool isPaid = rawPaymentStatus == 'paid' || rawPaymentStatus == 'مدفوع';
    final String paymentStatusText = isPaid ? 'مدفوع' : 'غير مدفوع';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('تفاصيل الطلب #$shortId',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        centerTitle: true,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('حالة الطلب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_translateStatus(status),
                            style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  if (status != 'completed' && status != 'cancelled') ...[
                    const SizedBox(height: 18),
                    _isUpdating
                        ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : Column(
                            children: [
                              if (status == 'pending')
                                _buildDragToConfirmSlider(
                                  text: '⟵ اسحب للبدء بالتجهيز',
                                  targetStatus: 'processing',
                                  activeColor: AppColors.primary,
                                ),

                              if (status == 'processing')
                                _buildDragToConfirmSlider(
                                  text: '⟵ اسحب لتأكيد الشحن',
                                  targetStatus: 'shipping',
                                  activeColor: const Color(0xFF1565C0),
                                ),

                              if (status == 'shipping')
                                _buildDragToConfirmSlider(
                                  text: '⟵ اسحب لتأكيد تسليم الطلب',
                                  targetStatus: 'completed',
                                  activeColor: Colors.green,
                                ),

                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _showCancelConfirmationDialog,
                                icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 16),
                                label: const Text('إلغاء الطلب'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('معلومات العميل والشحن',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text('اسم العميل: $customerName',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: customerPhone != '-' ? () => _makePhoneCall(customerPhone) : null,
                            child: Text(
                              'رقم الهاتف: $customerPhone',
                              style: TextStyle(
                                fontSize: 13,
                                color: customerPhone != '-' ? Colors.blue : AppColors.textPrimary,
                                decoration: customerPhone != '-' ? TextDecoration.underline : TextDecoration.none,
                                fontWeight: customerPhone != '-' ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (customerPhone != '-')
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          color: AppColors.primary,
                          tooltip: 'نسخ رقم الهاتف',
                          onPressed: () => _copyPhoneNumber(customerPhone),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('العنوان: $addressText',
                              style: TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                    ],
                  ),
                  if (coordinates != null && coordinates['lat'] != null && coordinates['lng'] != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openMap(coordinates!['lat'], coordinates['lng']),
                        icon: const Icon(Icons.map, color: Colors.green, size: 18),
                        label: const Text('عرض الموقع على الخريطة التفاعلية',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('عناصر الطلب (قائمة التجهيز)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 10),

            groupedItems.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text('لا توجد عناصر مسجلة في هذا الطلب',
                            style: TextStyle(color: AppColors.textSecondary))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groupedItems.length,
                    itemBuilder: (context, groupIndex) {
                      final group = groupedItems[groupIndex];
                      final isGrouped = group['isGrouped'] as bool;

                      if (!isGrouped) {
                        final item = group['item'];
                        final productId = item['product_id']?.toString();
                        final sourceId = productId;
                        final rawName = item['product_name'] ?? item['product']?['name'];
                        final itemName = _extractName(rawName, _fetchedItemNames[sourceId] ?? 'منتج');
                        final quantity = item['quantity'] ?? 1;
                        final unitPrice = (item['unit_price'] ?? 0).toDouble();
                        final itemTotal = unitPrice * quantity;
                        
                        final checkKey = item['id']?.toString() ?? 'single_$groupIndex';
                        final isChecked = _checkedKeys.contains(checkKey);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isChecked ? Colors.green.withOpacity(0.04) : AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: isChecked ? Colors.green.withOpacity(0.2) : AppColors.textSecondary.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isChecked,
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _checkedKeys.add(checkKey);
                                    } else {
                                      _checkedKeys.remove(checkKey);
                                    }
                                  });
                                },
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: productId != null ? () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: productId)));
                                  } : null,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                                          color: isChecked ? AppColors.textSecondary : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('الكمية: $quantity | السعر: $unitPrice ل.س', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                              Text('$itemTotal ل.س', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
                            ],
                          ),
                        );
                      } else {
                        final parentName = group['parent_name'] as String;
                        final subItems = group['sub_items'] as List<dynamic>;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.textSecondary.withOpacity(0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(parentName, style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              ...subItems.asMap().entries.map((entry) {
                                final subIndex = entry.key;
                                final sub = entry.value;
                                final productId = sub['product_id']?.toString() ?? 'unknown';
                                final sourceId = productId;
                                final subId = sub['id']?.toString() ?? 'sub_$subIndex';
                                final rawSubName = sub['product_name'] ?? sub['product']?['name'];
                                final subName = _extractName(rawSubName, _fetchedItemNames[sourceId] ?? 'منتج فرعي');
                                final quantity = sub['quantity'] ?? 1;
                                final unitPrice = (sub['unit_price'] ?? 0).toDouble();
                                
                                final checkKey = 'group_${group['source_id']}_item_$subId';
                                final isChecked = _checkedKeys.contains(checkKey);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: isChecked,
                                        activeColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _checkedKeys.add(checkKey);
                                            } else {
                                              _checkedKeys.remove(checkKey);
                                            }
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: InkWell(
                                          onTap: productId != 'unknown' ? () {
                                            Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: productId)));
                                          } : null,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                subName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: isChecked ? AppColors.textSecondary : AppColors.textPrimary,
                                                  decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text('الكمية: $quantity | السعر: $unitPrice ل.س', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }
                    },
                  ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('طريقة الدفع', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text(_currentOrder['payment_method'] ?? 'نقداً',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('حالة الدفع', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text(paymentStatusText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPaid ? Colors.green : Colors.orangeAccent,
                            fontSize: 13,
                          )),
                    ],
                  ),
                  if (_currentOrder['payment_details'] != null && _currentOrder['payment_details'] is Map) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('تفاصيل الدفع', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        if (_currentOrder['payment_details']['invoice_number'] != null)
                          Text('رقم الحوالة: ${_currentOrder['payment_details']['invoice_number']}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))
                        else if (_currentOrder['payment_details']['proof_url'] != null)
                          InkWell(
                            onTap: () => _openProofUrl(_currentOrder['payment_details']['proof_url']),
                            child: const Text('عرض إثبات التحويل (صورة/PDF)',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.indigoAccent,
                                    decoration: TextDecoration.underline)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المبلغ الإجمالي',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                      Text(
                        '${_currentOrder['total_amount'] ?? 0} ل.س',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}