import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'download_request.dart';
import 'download_item.dart';

final class DownloadResult {
  const DownloadResult({
    required this.filePath,
    required this.url,
    required this.bytes,
    required this.partialFilePath,
  });

  final String filePath;
  final String url;
  final int bytes;
  final String partialFilePath;
}

final class DownloadProgressUpdate {
  const DownloadProgressUpdate({
    required this.received,
    required this.total,
    required this.progress,
    required this.resumeBytes,
    required this.speedBytesPerSecond,
    required this.etaSeconds,
    required this.partialFilePath,
  });

  final int received;
  final int total;
  final double progress;
  final int resumeBytes;
  final double speedBytesPerSecond;
  final int etaSeconds;
  final String partialFilePath;
}

final class DownloadsRepository {
  DownloadsRepository({
    required Box box,
    required Dio dio,
    DownloadUrlResolver resolver = const DownloadUrlResolver(),
  }) : _box = box,
       _dio = dio,
       _resolver = resolver;

  final Box _box;
  final Dio _dio;
  final DownloadUrlResolver _resolver;
  final Map<String, CancelToken> _tokens = {};

  static const _itemsKey = 'items';

  List<DownloadItem> loadItems() {
    final rawItems = _box.get(_itemsKey);
    if (rawItems is! List) return const [];

    return rawItems
        .whereType<Map>()
        .map((item) => DownloadItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveItems(List<DownloadItem> items) async {
    await _box.put(_itemsKey, items.map((item) => item.toJson()).toList());
  }

  Future<DownloadResult> download(
    DownloadItem item, {
    required void Function(DownloadProgressUpdate progress) onProgress,
  }) async {
    final directory = await _downloadsBaseDirectory();
    final downloadsDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}Downloads',
    );
    if (!downloadsDirectory.existsSync()) {
      downloadsDirectory.createSync(recursive: true);
    }

    final filePath =
        '${downloadsDirectory.path}${Platform.pathSeparator}${item.filename}';
    final partialFilePath = '$filePath.part';
    final partialFile = File(partialFilePath);
    Object? lastError;
    final request = _resolvedRequestFor(item);
    final cancelToken = CancelToken();
    _tokens[item.id] = cancelToken;

    for (final url in request.candidateUrls) {
      try {
        var resumeBytes = partialFile.existsSync()
            ? partialFile.lengthSync()
            : 0;
        var append = resumeBytes > 0;

        final response = await _dio.get<ResponseBody>(
          url,
          options: Options(
            responseType: ResponseType.stream,
            receiveTimeout: Duration.zero,
            extra: const {'disableNetworkRetry': true},
            headers: request.headers(resumeFrom: resumeBytes),
          ),
          cancelToken: cancelToken,
        );

        final statusCode = response.statusCode ?? 200;
        if (statusCode == 200 && resumeBytes > 0) {
          partialFile.deleteSync();
          resumeBytes = 0;
          append = false;
        }

        final total = _contentLengthForResponse(response.headers) + resumeBytes;
        final sink = partialFile.openWrite(
          mode: append ? FileMode.append : FileMode.writeOnly,
        );
        var received = resumeBytes;
        var sampleBytes = resumeBytes;
        var sampleAt = DateTime.now();

        try {
          await for (final chunk in response.data!.stream) {
            if (cancelToken.isCancelled) {
              throw DioException(
                requestOptions: response.requestOptions,
                type: DioExceptionType.cancel,
                error: 'cancelled',
              );
            }

            sink.add(chunk);
            received += chunk.length;

            final now = DateTime.now();
            final elapsedMs = now.difference(sampleAt).inMilliseconds;
            final sampledBytes = received - sampleBytes;
            final speedBytesPerSecond = elapsedMs <= 0
                ? 0
                : sampledBytes * 1000 / elapsedMs;
            final etaSeconds = speedBytesPerSecond <= 0 || total <= 0
                ? 0
                : ((total - received) / speedBytesPerSecond).ceil();

            if (elapsedMs >= 600) {
              sampleAt = now;
              sampleBytes = received;
            }

            onProgress(
              DownloadProgressUpdate(
                received: received,
                total: total > 0 ? total : 0,
                progress: total <= 0 ? 0 : received / total,
                resumeBytes: resumeBytes,
                speedBytesPerSecond: speedBytesPerSecond.toDouble(),
                etaSeconds: etaSeconds,
                partialFilePath: partialFilePath,
              ),
            );
          }
        } finally {
          await sink.flush();
          await sink.close();
        }

        if (!partialFile.existsSync() || partialFile.lengthSync() == 0) {
          throw StateError('Downloaded file is empty.');
        }
        if (_looksLikeHtml(partialFile)) {
          throw StateError(
            'Download host returned an HTML page instead of video.',
          );
        }
        final finalFile = File(filePath);
        if (finalFile.existsSync()) {
          finalFile.deleteSync();
        }
        partialFile.renameSync(filePath);
        return DownloadResult(
          filePath: filePath,
          url: url,
          bytes: File(filePath).lengthSync(),
          partialFilePath: partialFilePath,
        );
      } catch (error) {
        lastError = error;
        if (error is DioException && error.type == DioExceptionType.cancel) {
          rethrow;
        }
        if (error is StateError) break;
      }
    }

    _tokens.remove(item.id);
    throw lastError ?? StateError('Download failed.');
  }

  void pause(String id) {
    _tokens.remove(id)?.cancel('paused');
  }

  void cancel(String id) {
    _tokens.remove(id)?.cancel('cancelled');
  }

  Future<Directory> _downloadsBaseDirectory() async {
    if (Platform.isAndroid) {
      final externalDirectory = await getExternalStorageDirectory();
      if (externalDirectory != null) return externalDirectory;
    }
    return getApplicationDocumentsDirectory();
  }

  bool _looksLikeHtml(File file) {
    final bytes = file.openSync().readSync(128);
    final prefix = String.fromCharCodes(bytes).trimLeft().toLowerCase();
    return prefix.startsWith('<!doctype html') || prefix.startsWith('<html');
  }

  int _contentLengthForResponse(Headers headers) {
    final value = headers.value(Headers.contentLengthHeader);
    return int.tryParse(value ?? '0') ?? 0;
  }

  ResolvedDownloadRequest _resolvedRequestFor(DownloadItem item) {
    if (item.referer.isNotEmpty && item.origin.isNotEmpty) {
      return ResolvedDownloadRequest(
        primaryUrl: item.url,
        candidateUrls: item.candidateUrls.isEmpty
            ? [item.url]
            : item.candidateUrls,
        referer: item.referer,
        origin: item.origin,
      );
    }
    return _resolver.resolve(url: item.url, downloadPage: item.downloadPage);
  }
}
