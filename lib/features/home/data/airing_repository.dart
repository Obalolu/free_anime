import 'package:dio/dio.dart';
import 'package:free_anime/core/network/api_exceptions.dart';

import 'airing_item.dart';

abstract interface class AiringRepository {
  Future<List<AiringItem>> fetchAiring({int page = 1});
}

final class AiringRepositoryImpl implements AiringRepository {
  AiringRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<AiringItem>> fetchAiring({int page = 1}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/airing',
        queryParameters: {'page': page},
      );
      final data = (response.data?['data'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AiringItem.fromJson)
          .toList();
      return data;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;
      final message = data is Map<String, dynamic>
          ? data['message']?.toString().toLowerCase() ?? ''
          : '';

      if (statusCode == 503 &&
          (message.contains('ddos-guard') ||
              message.contains('invalid cookies'))) {
        throw const ServiceProtectionException(
          'Source is temporarily protected by DDoS-Guard. Try again later or switch API mirror.',
        );
      }
      if (statusCode == 503) {
        throw const UpstreamUnavailableException();
      }
      rethrow;
    }
  }
}
