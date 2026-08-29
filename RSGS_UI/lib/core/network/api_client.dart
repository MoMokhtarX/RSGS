import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.errors});

  final int? statusCode;
  final String message;
  final dynamic errors;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    final uri = Uri.tryParse(baseUrl);
    final isLocalhost = uri != null &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1');

    if (kDebugMode && isLocalhost && uri.scheme == 'https') {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            _token = null;
            _onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          error: true,
        ),
      );
    }
  }

  static final instance = ApiClient._();

  late final Dio _dio;

  static const baseUrl = String.fromEnvironment(
    'RSGS_API_BASE_URL',
    defaultValue: 'https://localhost:7024',
  );

  String? _token;
  VoidCallback? _onUnauthorized;

  void setToken(String? token) => _token = token;

  void setUnauthorizedHandler(VoidCallback? handler) {
    _onUnauthorized = handler;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return _unwrap(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return _unwrap(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return _unwrap(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> patch(String path, {dynamic data}) async {
    try {
      final response = await _dio.patch(path, data: data);
      return _unwrap(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return _unwrap(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  dynamic _unwrap(Response response) {
    final body = response.data;
    if (body == null) return null;

    if (body is Map<String, dynamic> && body.containsKey('success')) {
      final success = body['success'] == true;
      final message = body['message']?.toString() ?? '';

      if (!success) {
        throw ApiException(
          response.statusCode,
          message.isEmpty ? 'The request failed.' : message,
          errors: body['errors'],
        );
      }

      return body['data'];
    }

    return body;
  }

  ApiException _handleError(DioException e) {
    final data = e.response?.data;

    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString();
      return ApiException(
        e.response?.statusCode,
        (message == null || message.isEmpty)
            ? (e.message ?? 'An unknown error occurred')
            : message,
        errors: data['errors'],
      );
    }

    return ApiException(
      e.response?.statusCode,
      e.message ?? 'An unknown error occurred',
    );
  }

  Future<List<int>> getBytes(String path) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? <int>[];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
