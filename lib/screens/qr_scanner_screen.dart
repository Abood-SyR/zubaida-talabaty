import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import '../services/session_service.dart';
import '../core/thems/app_colors.dart';

class QRScannerScreen extends StatefulWidget {
  final String baseUrl;

  const QRScannerScreen({super.key, required this.baseUrl});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isProcessing = false;
  bool _isCameraActive = false;
  
  // تعريف وحدة التحكم بشكل آمن تماماً للويب والهواتف
  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
  );

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _verifySession(String scannedData) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      String tokenToSend = scannedData;
      try {
        final decoded = jsonDecode(scannedData);
        if (decoded is Map && decoded.containsKey('session_token')) {
          tokenToSend = decoded['session_token'];
        }
      } catch (_) {}

      final response = await http.post(
        Uri.parse('${widget.baseUrl}/auth/verify-session-qr'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_token': tokenToSend}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'];

        if (accessToken == null || accessToken.isEmpty) {
          _showError('خطأ: السيرفر لم يقم بإرجاع توكن صالح');
          return;
        }

        final payload = _parseJwt(accessToken);
        final String sessionName = payload['session_name'] ?? 'معدّل';
        final String sessionId = payload['session_id'] ?? '';
        final List<String> allowedOrders = List<String>.from(payload['allowed_order_statuses'] ?? []);

        await SessionService.saveSession(
          token: accessToken,
          sessionName: sessionName,
          allowedStatuses: allowedOrders,
          sessionId: sessionId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('أهلاً بك $sessionName، تم حفظ الصلاحيات بنجاح'),
              backgroundColor: AppColors.primary,
            ),
          );
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          _showError(error['detail'] ?? 'فشل التحقق من رمز الجلسة');
        } catch (_) {
          _showError('فشل التحقق من رمز الجلسة');
        }
      }
    } catch (e) {
      _showError('خطأ في الاتصال بالسيرفر');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Map<String, dynamic> _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return jsonDecode(payload);
    } catch (e) {
      return {};
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // لصق النص من الحافظة مباشرة بدون أي نوافذ منبثقة
  Future<void> _pasteFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
      final pastedText = data.text!.trim();
      _verifySession(pastedText);
    } else {
      _showError('الحافظة فارغة أو لا تحتوي على نص صالح');
    }
  }

  // تبديل حالة تشغيل الكاميرا عبر زر الباركود
  Future<void> _toggleCamera() async {
    if (_isCameraActive) {
      await _scannerController.stop();
      setState(() => _isCameraActive = false);
    } else {
      await _scannerController.start();
      setState(() => _isCameraActive = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Zubaida-Beauty', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            if (barcode.rawValue != null && !_isProcessing) {
                              _verifySession(barcode.rawValue!);
                              break;
                            }
                          }
                        },
                      ),
                      if (!_isCameraActive && !_isProcessing)
                        Container(
                          color: AppColors.surface,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_scanner_rounded, size: 64, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  'اضغط على زر الباركود أدناه للبدء',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_isProcessing)
                        Container(
                          color: AppColors.background.withOpacity(0.8),
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 35),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleCamera,
                      icon: Icon(_isCameraActive ? Icons.stop_rounded : Icons.qr_code_scanner_rounded, color: Colors.white),
                      label: Text(_isCameraActive ? 'إيقاف الكاميرا' : 'تشغيل الباركود', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCameraActive ? Colors.redAccent : AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: Icon(Icons.paste_rounded, color: AppColors.primary),
                      label: Text('لصق الرمز', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}