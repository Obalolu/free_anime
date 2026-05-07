part of 'watch_cubit.dart';

enum WatchStatus { initial, loading, success, failure }

const _sentinel = Object();

final class WatchState extends Equatable {
  const WatchState({
    this.status = WatchStatus.initial,
    this.info,
    this.selectedSource,
    this.releases = const [],
    this.currentIndex,
    this.loadingDownloads = false,
    this.error,
  });

  final WatchStatus status;
  final WatchInfo? info;
  final WatchSource? selectedSource;
  final List<AnimeEpisodeRelease> releases;
  final int? currentIndex;
  final bool loadingDownloads;
  final String? error;

  AnimeEpisodeRelease? get currentRelease =>
      currentIndex == null ||
          currentIndex! < 0 ||
          currentIndex! >= releases.length
      ? null
      : releases[currentIndex!];

  AnimeEpisodeRelease? get previousRelease =>
      currentIndex == null || currentIndex! <= 0
      ? null
      : releases[currentIndex! - 1];

  AnimeEpisodeRelease? get nextRelease =>
      currentIndex == null ||
          currentIndex! < 0 ||
          currentIndex! >= releases.length - 1
      ? null
      : releases[currentIndex! + 1];

  WatchState copyWith({
    WatchStatus? status,
    WatchInfo? info,
    Object? selectedSource = _sentinel,
    List<AnimeEpisodeRelease>? releases,
    int? currentIndex,
    bool? loadingDownloads,
    String? error,
  }) {
    return WatchState(
      status: status ?? this.status,
      info: info ?? this.info,
      selectedSource: selectedSource == _sentinel
          ? this.selectedSource
          : selectedSource as WatchSource?,
      releases: releases ?? this.releases,
      currentIndex: currentIndex ?? this.currentIndex,
      loadingDownloads: loadingDownloads ?? this.loadingDownloads,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    info,
    selectedSource,
    releases,
    currentIndex,
    loadingDownloads,
    error,
  ];
}
