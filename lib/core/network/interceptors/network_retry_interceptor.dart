import 'dart:math';

import 'package:dio/dio.dart';

class NetworkRetryInterceptor extends Interceptor {
  NetworkRetryInterceptor(this._dio);

  final Dio _dio;
  final Random _random = Random();
  static const _maxRetries = 3;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final method = options.method.toUpperCase();
    final attempt = (options.extra['retryAttempt'] as int?) ?? 0;
    final disableRetry = options.extra['disableNetworkRetry'] == true;
    final allowUnsafe = options.extra['allowUnsafeNetworkRetry'] == true;
    final statusCode = err.response?.statusCode;
    final responseData = err.response?.data;
    final responseMessage = responseData is Map<String, dynamic>
        ? (responseData['message']?.toString().toLowerCase() ?? '')
        : '';
    final blockedByProtection =
        responseMessage.contains('ddos-guard') ||
        responseMessage.contains('invalid cookies');

    final isIdempotent = {
      'GET',
      'HEAD',
      'OPTIONS',
      'PUT',
      'DELETE',
    }.contains(method);
    final isRetriableStatus = {429, 502, 503, 504}.contains(statusCode);
    final isNetworkError =
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError;

    final canRetryMethod = isIdempotent || allowUnsafe;
    final shouldRetry =
        !blockedByProtection &&
        !disableRetry &&
        canRetryMethod &&
        attempt < _maxRetries &&
        (isRetriableStatus || isNetworkError);

    if (!shouldRetry) {
      return handler.next(err);
    }

    options.extra['retryAttempt'] = attempt + 1;
    final baseMs = 250 * (1 << attempt);
    final jitterMs = _random.nextInt(150);
    await Future<void>.delayed(Duration(milliseconds: baseMs + jitterMs));

    try {
      final response = await _dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }
}
