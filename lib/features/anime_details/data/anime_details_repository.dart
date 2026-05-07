import 'package:dio/dio.dart';
import 'package:free_anime/core/network/api_exceptions.dart';

import 'anime_details_models.dart';

abstract interface class AnimeDetailsRepository {
  Future<AnimeDetails> fetchDetails(String session);
  Future<List<AnimeEpisodeRelease>> fetchReleases(String session);
  Future<AnimeReleasesPage> fetchReleasesPage(
    String session, {
    required int page,
  });
}

final class AnimeDetailsRepositoryImpl implements AnimeDetailsRepository {
  AnimeDetailsRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<AnimeDetails> fetchDetails(String session) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/$session');
      final data = response.data;
      if (data == null) {
        throw const UpstreamUnavailableException('Details response is empty.');
      }
      return AnimeDetails.fromJson(data);
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
          'Anime details are temporarily blocked by DDoS-Guard. Try again shortly.',
        );
      }
      if (statusCode == 503) {
        throw const UpstreamUnavailableException();
      }
      rethrow;
    }
  }

  @override
  Future<List<AnimeEpisodeRelease>> fetchReleases(String session) async {
    final firstPage = await fetchReleasesPage(session, page: 1);
    if (!firstPage.hasMore) return firstPage.releases;

    final releases = [...firstPage.releases];
    for (var page = firstPage.currentPage + 1; page <= firstPage.lastPage; page++) {
      final nextPage = await fetchReleasesPage(session, page: page);
      releases.addAll(nextPage.releases);
    }
    return _deduplicateBySession(releases);
  }

  @override
  Future<AnimeReleasesPage> fetchReleasesPage(
    String session, {
    required int page,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/$session/releases',
        queryParameters: {'sort': 'episode_asc', 'page': page},
      );
      final body = response.data ?? const <String, dynamic>{};
      final rawItems = body['data'];
      final releases = rawItems is! List
          ? const <AnimeEpisodeRelease>[]
          : rawItems
                .whereType<Map<String, dynamic>>()
                .map(AnimeEpisodeRelease.fromJson)
                .toList();
      final paginationInfo = body['paginationInfo'];
      final currentPage = _parseCurrentPage(paginationInfo, fallback: page);
      final inferredLastPage = _parseLastPage(
        paginationInfo,
        fallback: currentPage,
      );
      final lastPage = inferredLastPage < currentPage
          ? currentPage
          : inferredLastPage;

      return AnimeReleasesPage(
        releases: releases,
        currentPage: currentPage,
        lastPage: lastPage,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return const AnimeReleasesPage(
          releases: <AnimeEpisodeRelease>[],
          currentPage: 1,
          lastPage: 1,
        );
      }
      rethrow;
    }
  }

  int _parseCurrentPage(dynamic paginationInfo, {required int fallback}) {
    if (paginationInfo is! Map<String, dynamic>) return fallback;
    return _readInt(
          paginationInfo,
          const ['currentPage', 'current_page', 'page'],
        ) ??
        fallback;
  }

  int _parseLastPage(dynamic paginationInfo, {required int fallback}) {
    if (paginationInfo is! Map<String, dynamic>) return fallback;
    return _readInt(
          paginationInfo,
          const ['lastPage', 'last_page', 'totalPages', 'total_pages', 'pages'],
        ) ??
        fallback;
  }

  int? _readInt(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final parsed = int.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  List<AnimeEpisodeRelease> _deduplicateBySession(
    List<AnimeEpisodeRelease> releases,
  ) {
    final seenSessions = <String>{};
    final deduplicated = <AnimeEpisodeRelease>[];
    for (final release in releases) {
      final session = release.session.trim();
      if (session.isNotEmpty && !seenSessions.add(session)) continue;
      deduplicated.add(release);
    }
    return deduplicated;
  }
}
