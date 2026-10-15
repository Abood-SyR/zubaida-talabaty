// ============================================================
// product_details_screen.dart (عرض الصور بوضع contain مع خلفية بيضاء ثابتة)
// ============================================================
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/session_service.dart';
import '../core/thems/app_colors.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _productData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
  }

  Future<void> _fetchProductDetails() async {
    try {
      final token = await SessionService.getToken();
      
      final Dio dio = Dio(BaseOptions(
        baseUrl: 'https://resonta-yalla-match-notifications.hf.space',
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ));

      Response response = await dio.get('/products/${widget.productId}');
      
      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _productData = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'تعذر تحميل بيانات المنتج';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل الاتصال بالخادم، تأكد من اتصالك بالإنترنت';
        _isLoading = false;
      });
    }
  }

  String _extractLocalizedText(dynamic rawValue, String fallback) {
    if (rawValue is String && rawValue.isNotEmpty) return rawValue;
    if (rawValue is Map) {
      return rawValue['ar'] ?? rawValue['en'] ?? (rawValue.values.isNotEmpty ? rawValue.values.first.toString() : fallback);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    List<String> allImages = [];
    if (_productData != null) {
      if (_productData!['thumbnail_url'] != null) {
        allImages.add(_productData!['thumbnail_url'].toString());
      }
      if (_productData!['images'] is List) {
        for (var img in _productData!['images']) {
          if (img != null && img.toString().isNotEmpty) {
            allImages.add(img.toString());
          }
        }
      }
      allImages = allImages.toSet().toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'تفاصيل المنتج',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
                  ),
                )
              : _productData == null
                  ? Center(child: Text('لا توجد بيانات متاحة لهذا المنتج', style: TextStyle(color: AppColors.textSecondary)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (allImages.isNotEmpty)
                            SizedBox(
                              height: 250,
                              child: PageView.builder(
                                itemCount: allImages.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white, // خلفية بيضاء ثابتة دائماً
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        allImages[index],
                                        fit: BoxFit.contain, // عرض الصورة كاملة دون قص
                                        cacheWidth: 800,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      (loadingProgress.expectedTotalBytes ?? 1)
                                                  : null,
                                              color: AppColors.primary,
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.white,
                                          child: Icon(Icons.image_not_supported, size: 50, color: AppColors.textSecondary),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 20),
                          
                          Text(
                            _extractLocalizedText(_productData!['name'] ?? _productData!['title'], 'منتج بدون اسم'),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('السعر:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_productData!['price'] ?? 0} ل.س',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('الكمية المتاحة:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_productData!['stock_quantity'] ?? 0} قطعة',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (_productData!['description'] != null) ...[
                            Text('الوصف:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _extractLocalizedText(_productData!['description'], ''),
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (_productData!['usage_instructions'] != null) ...[
                            Text('طريقة الاستخدام:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _extractLocalizedText(_productData!['usage_instructions'], ''),
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (_productData!['ingredients'] != null) ...[
                            Text('المكونات:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _extractLocalizedText(_productData!['ingredients'], ''),
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}