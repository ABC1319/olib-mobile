import 'package:dio/dio.dart';
import '../config/env.dart';
import '../models/backend_response.dart';

class BackendApi {
  late final Dio _dio;

  BackendApi({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? Env.authUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  Future<AnonTokenResponse> register({
    required String deviceId,
    String platform = 'android',
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'device_id': deviceId,
      'platform': platform,
    });
    return _parseResponse(response, AnonTokenResponse.fromJson);
  }

  Future<QrCodeResponse> getQrCode(String token) async {
    final response = await _dio.get(
      '/auth/qrcode',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return _parseResponse(response, QrCodeResponse.fromJson);
  }

  Future<AuthStatusResponse> checkStatus(String token) async {
    final response = await _dio.get(
      '/auth/status',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return _parseResponse(response, AuthStatusResponse.fromJson);
  }

  T _parseResponse<T>(Response response, T Function(Map<String, dynamic>) fromJson) {
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true && body['data'] != null) {
      return fromJson(body['data'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? '请求失败');
  }
}
