import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import 'package:free_anime/features/downloads/data/download_item.dart';
import 'package:free_anime/features/downloads/data/downloads_repository.dart';

part 'downloads_state.dart';

class DownloadsCubit extends Cubit<DownloadsState> {
  DownloadsCubit({required DownloadsRepository repository})
    : _repository = repository,
      super(const DownloadsState());

  final DownloadsRepository _repository;

  Future<void> load() async {
    final items = _repository.loadItems();
    emit(state.copyWith(items: items));
    for (final item in items.where(
      (item) => item.status == DownloadStatus.downloading,
    )) {
      _updateItem(
        item.copyWith(
          status: DownloadStatus.paused,
          error: 'Download paused when the app closed.',
        ),
      );
    }
  }

  Future<void> enqueue(DownloadItem item) async {
    if (state.items.any(
      (existing) =>
          existing.matchesIdentity(item) &&
          existing.matchesVariant(item) &&
          existing.status != DownloadStatus.cancelled,
    )) {
      return;
    }

    emit(state.copyWith(items: [item, ...state.items]));
    await _save();
    await _start(item);
  }

  DownloadItem? latestForEpisode(String animeSession, String episodeSession) {
    return state.latestForEpisode(animeSession, episodeSession);
  }

  DownloadItem? completedDownloadFor(
    String animeSession,
    String episodeSession,
  ) {
    return state.completedDownloadFor(animeSession, episodeSession);
  }

  Future<void> retry(String id) async {
    final matches = state.items.where((item) => item.id == id).toList();
    final item = matches.isEmpty ? null : matches.first;
    if (item == null) return;

    final queued = item.copyWith(
      status: DownloadStatus.queued,
      progress: 0,
      receivedBytes: 0,
      totalBytes: 0,
      resumeBytes: 0,
      speedBytesPerSecond: 0,
      etaSeconds: 0,
      error: '',
    );
    _updateItem(queued);
    await _start(queued);
  }

  Future<void> pause(String id) async {
    final item = _itemById(id);
    if (item == null || item.status != DownloadStatus.downloading) return;
    _repository.pause(id);
    _updateItem(
      item.copyWith(
        status: DownloadStatus.paused,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        error: '',
      ),
    );
  }

  Future<void> resume(String id) async {
    final item = _itemById(id);
    if (item == null || !item.canResume) return;
    final resumed = item.copyWith(
      status: DownloadStatus.queued,
      error: '',
      speedBytesPerSecond: 0,
      etaSeconds: 0,
    );
    _updateItem(resumed);
    await _start(resumed);
  }

  Future<void> cancel(String id) async {
    final item = _itemById(id);
    if (item == null) return;
    _repository.cancel(id);
    _updateItem(
      item.copyWith(
        status: DownloadStatus.cancelled,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        error: '',
      ),
    );
  }

  Future<void> remove(String id) async {
    final item = _itemById(id);
    if (item != null && item.isActive) {
      _repository.cancel(id);
    }
    emit(
      state.copyWith(
        items: state.items.where((item) => item.id != id).toList(),
      ),
    );
    await _save();
  }

  Future<void> _start(DownloadItem item) async {
    _updateItem(item.copyWith(status: DownloadStatus.downloading, error: ''));
    try {
      final result = await _repository.download(
        item,
        onProgress: (progress) {
          _updateItem(
            item.copyWith(
              status: DownloadStatus.downloading,
              progress: progress.progress,
              receivedBytes: progress.received,
              totalBytes: progress.total,
              resumeBytes: progress.resumeBytes,
              partialFilePath: progress.partialFilePath,
              speedBytesPerSecond: progress.speedBytesPerSecond,
              etaSeconds: progress.etaSeconds,
            ),
          );
        },
      );
      _updateItem(
        item.copyWith(
          url: result.url,
          status: DownloadStatus.completed,
          progress: 1,
          receivedBytes: result.bytes,
          totalBytes: result.bytes,
          resumeBytes: result.bytes,
          partialFilePath: result.partialFilePath,
          speedBytesPerSecond: 0,
          etaSeconds: 0,
          filePath: result.filePath,
        ),
      );
    } catch (error) {
      if (error is DioException && error.type == DioExceptionType.cancel) {
        final latest = _itemById(item.id);
        if (latest != null && latest.status == DownloadStatus.cancelled) {
          return;
        }
        if (latest != null) {
          _updateItem(
            latest.copyWith(
              status: DownloadStatus.paused,
              speedBytesPerSecond: 0,
              etaSeconds: 0,
              error: '',
            ),
          );
        }
        return;
      }
      _updateItem(
        item.copyWith(
          status: DownloadStatus.failed,
          speedBytesPerSecond: 0,
          etaSeconds: 0,
          error: error.toString(),
        ),
      );
    }
  }

  DownloadItem? _itemById(String id) {
    final matches = state.items.where((item) => item.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  void _updateItem(DownloadItem updated) {
    emit(
      state.copyWith(
        items: state.items
            .map((item) => item.id == updated.id ? updated : item)
            .toList(),
      ),
    );
    _save();
  }

  Future<void> _save() => _repository.saveItems(state.items);
}
