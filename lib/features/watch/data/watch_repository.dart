import 'package:dio/dio.dart';

import 'package:free_anime/features/downloads/data/download_request.dart';

import 'watch_models.dart';

abstract interface class WatchRepository {
  Future<WatchInfo> fetchWatchInfo({
    required String animeSession,
    required String episodeSession,
    required bool includeDownloads,
  });

  Future<String> resolveDownloadUrl(String paheUrl);
}

final class WatchRepositoryImpl implements WatchRepository {
  WatchRepositoryImpl({
    required Dio dio,
    DownloadUrlResolver resolver = const DownloadUrlResolver(),
  }) : _dio = dio,
       _resolver = resolver;

  final Dio _dio;
  final DownloadUrlResolver _resolver;

  @override
  Future<WatchInfo> fetchWatchInfo({
    required String animeSession,
    required String episodeSession,
    required bool includeDownloads,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/play/$animeSession',
      queryParameters: {
        'episodeId': episodeSession,
        if (!includeDownloads) 'downloads': 'false',
      },
    );
    final data = response.data;
    if (data == null) throw StateError('Watch response is empty.');

    return WatchInfo.fromJson(data);
  }

  @override
  Future<String> resolveDownloadUrl(String paheUrl) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/play/download-links',
      queryParameters: {'url': paheUrl},
    );
    final data = response.data;
    final downloadUrl =
        data?['downloadUrl']?.toString() ?? data?['url']?.toString() ?? '';
    if (downloadUrl.isEmpty) {
      throw StateError('Download resolver returned no URL.');
    }
    return _resolver.resolve(url: downloadUrl, downloadPage: '').primaryUrl;
  }
}
