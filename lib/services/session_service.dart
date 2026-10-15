// ============================================================
// session_service.dart (محدث مع تتبع الطباعة للتشخيص)
// ============================================================
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class SessionService {
  static const String _tokenKey = 'access_token';
  static const String _sessionNameKey = 'session_name';
  static const String _allowedStatusesKey = 'allowed_order_statuses';
  static const String _sessionIdKey = 'session_id'; // مفتاح معرف الجلسة

  // حفظ بيانات الدخول والصلاحيات ومعرف الجلسة
  static Future<void> saveSession({
    required String token,
    required String sessionName,
    required List<String> allowedStatuses,
    required String sessionId,
  }) async {
    print('DEBUG [Flutter]: Saving session -> ID: $sessionId, Name: $sessionName, Token: $token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_sessionNameKey, sessionName);
    await prefs.setStringList(_allowedStatusesKey, allowedStatuses);
    await prefs.setString(_sessionIdKey, sessionId);
  }

  static Future<String?> getSessionName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_sessionNameKey);
    print('DEBUG [Flutter]: getSessionName -> $name');
    return name;
  }

  static Future<List<String>> getAllowedStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final statuses = prefs.getStringList(_allowedStatusesKey) ?? [];
    print('DEBUG [Flutter]: getAllowedStatuses -> $statuses');
    return statuses;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    print('DEBUG [Flutter]: getToken retrieved -> ${token != null && token.isNotEmpty ? "Token exists (Length: ${token.length})" : "TOKEN IS NULL OR EMPTY!"}');
    print('DEBUG [Flutter]: Full Token Value -> $token');
    return token;
  }

  // جلب معرف الجلسة للاستماع اللحظي
  static Future<String?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_sessionIdKey);
    print('DEBUG [Flutter]: getSessionId -> $id');
    return id;
  }

  static Future<void> clearSession() async {
    print('DEBUG [Flutter]: Clearing session data');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // --- دالة مساعدة لإنشاء عميل Dio جاهز ومرفق به التوكن تلقائياً ---
  static Future<Dio> getDioClient() async {
    final token = await getToken();
    
    print('DEBUG [Flutter]: Building Dio client. Attached Token: ${token != null && token.isNotEmpty ? "${token.substring(0, 10)}..." : "NONE"}');

    final Dio dio = Dio(BaseOptions(
      baseUrl: 'https://resonta-yalla-match-notifications.hf.space',
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ));

    return dio;
  }
}