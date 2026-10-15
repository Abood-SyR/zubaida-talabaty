import 'package:dio/dio.dart';
import 'session_service.dart';

class DioClient {
  static Future<Dio> getInstance() async {
    final token = await SessionService.getToken();
    
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