import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiTimeoutException extends ApiException {
  const ApiTimeoutException() : super('서버 응답 시간이 초과되었습니다.');
}

class ApiService {
  ApiService({
    http.Client? client,
    this.baseUrl = AppConfig.apiBaseUrl,
    this.userId = AppConfig.defaultUserId,
    String? conversationId,
    this.requestTimeout = AppConfig.requestTimeout,
    this.chatTimeout = AppConfig.llmRequestTimeout,
  }) : conversationId =
           conversationId ?? 'flutter-${DateTime.now().microsecondsSinceEpoch}',
       _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final String userId;
  final String conversationId;
  final Duration requestTimeout;
  final Duration chatTimeout;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=UTF-8',
    'X-User-Id': userId,
  };

  Future<List<dynamic>> getList(String path) async {
    final response = await _withTimeout(
      _client.get(Uri.parse('$baseUrl$path'), headers: _headers),
      requestTimeout,
    );
    _ensureSuccess(response);
    return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _withTimeout(
      _client.get(Uri.parse('$baseUrl$path'), headers: _headers),
      requestTimeout,
    );
    _ensureSuccess(response);
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    final response = await _withTimeout(
      _client.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      timeout ?? requestTimeout,
    );
    _ensureSuccess(response);
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _withTimeout(
      _client.patch(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      requestTimeout,
    );
    _ensureSuccess(response);
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<void> delete(String path) async {
    final response = await _withTimeout(
      _client.delete(Uri.parse('$baseUrl$path'), headers: _headers),
      requestTimeout,
    );
    _ensureSuccess(response);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? detail;
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map<String, dynamic>) detail = body['detail']?.toString();
      } on FormatException {
        detail = null;
      }
      throw ApiException(
        detail == null
            ? 'API 오류 (${response.statusCode})'
            : 'API 오류 (${response.statusCode}): $detail',
      );
    }
  }

  Future<T> _withTimeout<T>(Future<T> request, Duration timeout) async {
    try {
      return await request.timeout(timeout);
    } on TimeoutException {
      throw const ApiTimeoutException();
    }
  }
}
