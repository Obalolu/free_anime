import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:free_anime/features/anime_details/data/anime_details_models.dart';
import 'package:free_anime/features/anime_details/data/anime_details_repository.dart';
import 'package:free_anime/features/watch/data/watch_models.dart';
import 'package:free_anime/features/watch/data/watch_repository.dart';

part 'watch_state.dart';

class WatchCubit extends Cubit<WatchState> {
  WatchCubit({
    required WatchRepository repository,
    required AnimeDetailsRepository animeDetailsRepository,
  }) : _repository = repository,
       _animeDetailsRepository = animeDetailsRepository,
       super(const WatchState());

  final WatchRepository _repository;
  final AnimeDetailsRepository _animeDetailsRepository;
  String? _animeSession;
  String? _episodeSession;

  Future<void> load({
    required String animeSession,
    required String episodeSession,
    String? preferredSourceUrl,
  }) async {
    _animeSession = animeSession;
    _episodeSession = episodeSession;
    emit(state.copyWith(status: WatchStatus.loading, error: null));
    try {
      final results = await Future.wait([
        _repository.fetchWatchInfo(
          animeSession: animeSession,
          episodeSession: episodeSession,
          includeDownloads: false,
        ),
        _safeFetchReleases(animeSession),
      ]);
      final info = results[0] as WatchInfo;
      final releases = results[1] as List<AnimeEpisodeRelease>;
      final currentIndex = releases.indexWhere(
        (release) => release.session == episodeSession,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: WatchStatus.success,
          info: info,
          selectedSource: _pickInitialSource(
            info,
            preferredSourceUrl: preferredSourceUrl,
          ),
          releases: releases,
          currentIndex: currentIndex >= 0 ? currentIndex : null,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(status: WatchStatus.failure, error: error.toString()),
      );
    }
  }

  void selectSource(WatchSource source) {
    emit(state.copyWith(selectedSource: source, error: null));
  }

  void setPlayerError(String message) {
    emit(state.copyWith(error: message));
  }

  Future<void> goToEpisode(int index) async {
    final animeSession = _animeSession;
    final releases = state.releases;
    if (animeSession == null || index < 0 || index >= releases.length) return;
    final release = releases[index];
    if (release.session.isEmpty) return;
    await load(
      animeSession: animeSession,
      episodeSession: release.session,
      preferredSourceUrl: state.selectedSource?.url,
    );
  }

  Future<void> loadDownloads() async {
    final animeSession = _animeSession;
    final episodeSession = _episodeSession;
    final info = state.info;
    if (animeSession == null ||
        episodeSession == null ||
        info == null ||
        state.loadingDownloads) {
      return;
    }
    if (info.downloads.isNotEmpty) return;

    emit(state.copyWith(loadingDownloads: true, error: null));
    try {
      final infoWithDownloads = await _repository.fetchWatchInfo(
        animeSession: animeSession,
        episodeSession: episodeSession,
        includeDownloads: true,
      );
      if (isClosed) return;
      emit(state.copyWith(info: infoWithDownloads, loadingDownloads: false));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(loadingDownloads: false, error: error.toString()));
    }
  }

  Future<String> resolveDownloadUrl(WatchDownload download) async {
    if (download.pahe.trim().isEmpty) return download.download;
    return _repository.resolveDownloadUrl(download.pahe);
  }

  Future<List<AnimeEpisodeRelease>> _safeFetchReleases(String session) async {
    try {
      return await _animeDetailsRepository.fetchReleases(session);
    } catch (_) {
      return const [];
    }
  }

  WatchSource? _pickInitialSource(
    WatchInfo info, {
    required String? preferredSourceUrl,
  }) {
    if (preferredSourceUrl != null && preferredSourceUrl.trim().isNotEmpty) {
      for (final source in info.sources) {
        if (source.url == preferredSourceUrl) return source;
      }
    }
    return info.defaultSource;
  }
}
