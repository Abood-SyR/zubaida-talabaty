// ============================================================
// orders_tab_screen.dart (مع الاعتماد الكلي على AppColors للألوان)
// ============================================================
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_service.dart';
import 'order_details_screen.dart';
import '../core/thems/app_colors.dart';

class OrdersTabScreen extends StatefulWidget {
  final List<String> allowedStatuses;
  final String? initialSelectedOrderId;

  const OrdersTabScreen({
    super.key, 
    required this.allowedStatuses,
    this.initialSelectedOrderId, 
    required String orderId,
  });

  @override
  State<OrdersTabScreen> createState() => _OrdersTabScreenState();
}

class _OrdersTabScreenState extends State<OrdersTabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> _activeStatuses = [];

  @override
  void initState() {
    super.initState();
    final allPossible = ['pending', 'processing', 'shipping', 'completed'];
    _activeStatuses = allPossible.where((s) => widget.allowedStatuses.contains(s)).toList();
    _tabController = TabController(length: _activeStatuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _translateStatusKey(String status) {
    switch (status) {
      case 'pending': return 'قيد المراجعة';
      case 'processing': return 'تحتاج تجهيز';
      case 'shipping': return 'تحتاج توصيل';
      case 'completed': return 'المنجزة';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeStatuses.isEmpty) {
      return Center(
        child: Text(
          'لا توجد أي صلاحيات متاحة لحسابك حالياً.',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(55),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppColors.surface,
                unselectedLabelColor: AppColors.textSecondary,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: AppColors.primary,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                tabs: _activeStatuses.map((status) => Tab(text: _translateStatusKey(status))).toList(),
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _activeStatuses.map((status) => OrdersListTabContent(
          statusFilter: status,
          initialSelectedOrderId: widget.initialSelectedOrderId,
        )).toList(),
      ),
    );
  }
}

class OrdersListTabContent extends StatefulWidget {
  final String statusFilter;
  final String? initialSelectedOrderId;

  const OrdersListTabContent({
    super.key, 
    required this.statusFilter,
    this.initialSelectedOrderId,
  });

  @override
  State<OrdersListTabContent> createState() => _OrdersListTabContentState();
}

class _OrdersListTabContentState extends State<OrdersListTabContent> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;
  List<dynamic> _orders = [];
  List<dynamic> _filteredOrders = [];
  String? _errorMessage;

  DateTime? _lastFetchTime;
  int _newIncomingCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCachedOrdersAndFetch();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_filterOrders);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _cacheKey => 'cached_orders_${widget.statusFilter}';
  String get _countKey => 'cached_count_${widget.statusFilter}';

  Future<void> _loadCachedOrdersAndFetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(_cacheKey);
      if (cachedString != null) {
        final List<dynamic> cachedList = jsonDecode(cachedString);
        if (mounted) {
          setState(() {
            _orders = cachedList;
            _filteredOrders = _orders;
            _isLoading = false;
          });
        }
      }
    } catch (_) {}

    await _fetchOrders();
  }

  Future<void> _saveOrdersToCache(List<dynamic> ordersList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(ordersList));
      await prefs.setInt(_countKey, ordersList.length);
    } catch (_) {}
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _fetchOrders(loadMore: true);
    }
  }

  void _filterOrders() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredOrders = _orders);
    } else {
      setState(() {
        _filteredOrders = _orders.where((order) {
          final orderId = order['id'].toString().toLowerCase();
          final address = order['shipping_address'];
          String name = '';
          String phone = '';
          if (address is Map) {
            name = (address['name'] ?? '').toString().toLowerCase();
            phone = (address['phone'] ?? '').toString().toLowerCase();
          }
          return orderId.contains(query) || name.contains(query) || phone.contains(query);
        }).toList();
      });
    }
  }

  Future<void> _fetchOrders({bool loadMore = false}) async {
    if (!loadMore && _lastFetchTime != null) {
      final difference = DateTime.now().difference(_lastFetchTime!);
      if (difference.inSeconds < 10) {
        final remaining = 10 - difference.inSeconds;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى الانتظار $remaining ثوانٍ قبل تحديث الطلبات مرة أخرى.'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.primary,
          ),
        );
        return;
      }
    }
    _lastFetchTime = DateTime.now();

    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      if (_orders.isEmpty) {
        setState(() => _isLoading = true);
      }
      _offset = 0;
      _hasMore = true;
    }

    try {
      final Dio dio = await SessionService.getDioClient();
      Response response = await dio.get(
        '/orders/',
        queryParameters: {'limit': _limit, 'offset': _offset, 'status': widget.statusFilter},
      );
      
      final List<dynamic> newOrders = response.data;
      if (mounted) {
        setState(() {
          if (loadMore) {
            final existingIds = _orders.map((o) => o['id'].toString()).toSet();
            final uniqueNew = newOrders.where((o) => !existingIds.contains(o['id'].toString())).toList();
            _orders.addAll(uniqueNew);
          } else {
            int oldLen = _orders.length;
            try {
              SharedPreferences.getInstance().then((prefs) {
                oldLen = prefs.getInt(_countKey) ?? _orders.length;
              });
            } catch (_) {}

            List<dynamic> mergedList = List.from(newOrders);
            if (_orders.isNotEmpty) {
              final newIds = newOrders.map((o) => o['id'].toString()).toSet();
              for (var oldOrder in _orders) {
                if (!newIds.contains(oldOrder['id'].toString())) {
                  mergedList.add(oldOrder);
                }
              }
            }

            mergedList.sort((a, b) {
              final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
              final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
              return bDate.compareTo(aDate);
            });

            if (_orders.isNotEmpty && mergedList.length > oldLen) {
              _newIncomingCount = mergedList.length - oldLen;
            } else {
              _newIncomingCount = 0;
            }

            _orders = mergedList;
            _saveOrdersToCache(_orders);
          }

          _filteredOrders = _orders;
          _filterOrders();
          if (newOrders.length < _limit) _hasMore = false;
          _offset += _limit;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_orders.isEmpty) {
            _errorMessage = 'فشل تحميل الطلبات. تحقق من الاتصال.';
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'pending': return 'قيد المراجعة';
      case 'processing': return 'قيد التجهيز';
      case 'shipping': return 'جاري الشحن';
      case 'completed': return 'مكتمل';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.primary;
      case 'processing': return AppColors.primary;
      case 'shipping': return AppColors.textPrimary;
      case 'completed': return AppColors.primary;
      case 'cancelled': return AppColors.textSecondary;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.textSecondary.withOpacity(0.12)),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'ابحث برقم الطلب، اسم العميل، أو الهاتف...',
                hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppColors.textSecondary, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _filterOrders();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),

        Expanded(
          child: _isLoading && _orders.isEmpty
              ? _buildShimmerLoader()
              : _errorMessage != null && _orders.isEmpty
                  ? Center(child: Text(_errorMessage!, style: TextStyle(color: AppColors.textPrimary)))
                  : _filteredOrders.isEmpty
                      ? Center(
                          child: Text(
                            'لا توجد طلبات مطابقة',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          onRefresh: () => _fetchOrders(),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            itemCount: _filteredOrders.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _filteredOrders.length) {
                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                                );
                              }

                              final order = _filteredOrders[index];
                              final String orderId = order['id'].toString();
                              final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
                              final status = order['status'] ?? widget.statusFilter;
                              
                              final String paymentStatus = order['payment_status'] ?? 'unpaid';
                              final bool isPaid = paymentStatus == 'paid';

                              final address = order['shipping_address'];
                              String name = 'زائر';
                              String phone = '-';
                              if (address is Map) {
                                name = address['name'] ?? 'بدون اسم';
                                phone = address['phone'] ?? '-';
                              }

                              final bool isNewIncoming = index < _newIncomingCount || 
                                  (widget.initialSelectedOrderId != null && 
                                  (orderId.toLowerCase().contains(widget.initialSelectedOrderId!.toLowerCase()) || 
                                   widget.initialSelectedOrderId!.toLowerCase().contains(orderId.toLowerCase())));

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: isNewIncoming ? AppColors.primary.withOpacity(0.08) : AppColors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isNewIncoming ? AppColors.primary : AppColors.textSecondary.withOpacity(0.08),
                                    width: isNewIncoming ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isNewIncoming ? AppColors.primary.withOpacity(0.15) : Colors.black.withOpacity(0.04),
                                      blurRadius: isNewIncoming ? 12 : 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => OrderDetailsScreen(orderData: order),
                                        ),
                                      ).then((_) => _fetchOrders());
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'طلب #$shortId',
                                                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'طريقة الدفع: ${order['payment_method'] ?? 'غير متوفر'}',
                                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(status).withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  _translateStatus(status),
                                                  style: TextStyle(color: _getStatusColor(status), fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textSecondary),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        name,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Icon(Icons.phone_outlined, size: 15, color: AppColors.textSecondary),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      phone,
                                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${order['total_amount']} ل.س',
                                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withOpacity(isPaid ? 0.12 : 0.05),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      isPaid ? 'مدفوع' : 'غير مدفوع',
                                                      style: TextStyle(
                                                        color: isPaid ? AppColors.primary : AppColors.textSecondary,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoader() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface.withOpacity(0.5),
      highlightColor: AppColors.background.withOpacity(0.8),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          height: 105,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}