import 'dart:async';

import 'package:dio/dio.dart';
import 'package:free_anime/core/network/api_exceptions.dart';

import 'search_local_store.dart';
import 'search_item.dart';

abstract interface class SearchRepository {
  Future<List<SearchItem>> search({required String query, int page = 1});
  List<String> loadRecentQueries();
  Future<void> clearRecentQueries();
}

final class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({required Dio dio, required SearchLocalStore localStore})
    : _dio = dio,
      _localStore = localStore;

  final Dio _dio;
  final SearchLocalStore _localStore;

  @override
  Future<List<SearchItem>> search({required String query, int page = 1}) async {
    final cached = _localStore.loadCachedResults(query, page);
    if (cached != null && cached.isNotEmpty) {
      unawaited(_localStore.saveRecentQuery(query));
      return cached;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/search',
        queryParameters: {'q': query, 'page': page},
      );
      final items = (response.data?['data'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SearchItem.fromJson)
          .toList();
      await _localStore.saveRecentQuery(query);
      await _localStore.saveCachedResults(query, page, items);
      return items;
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
          'Search source is temporarily protected by DDoS-Guard. Try again later or switch API mirror.',
        );
      }
      if (statusCode == 503) {
        throw const UpstreamUnavailableException();
      }
      rethrow;
    }
  }

  @override
  List<String> loadRecentQueries() => _localStore.loadRecentQueries();

  @override
  Future<void> clearRecentQueries() => _localStore.clearRecentQueries();
}
