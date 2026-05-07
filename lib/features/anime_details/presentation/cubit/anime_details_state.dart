part of 'anime_details_cubit.dart';

enum AnimeDetailsStatus { initial, loading, success, failure }

class AnimeDetailsState extends Equatable {
  const AnimeDetailsState({
    this.status = AnimeDetailsStatus.initial,
    this.details,
    this.releases = const [],
    this.nextReleasesPage = 1,
    this.lastReleasesPage = 1,
    this.loadingMoreReleases = false,
    this.error,
  });

  final AnimeDetailsStatus status;
  final AnimeDetails? details;
  final List<AnimeEpisodeRelease> releases;
  final int nextReleasesPage;
  final int lastReleasesPage;
  final bool loadingMoreReleases;
  final String? error;

  bool get hasMoreReleases => nextReleasesPage <= lastReleasesPage;

  AnimeDetailsState copyWith({
    AnimeDetailsStatus? status,
    AnimeDetails? details,
    List<AnimeEpisodeRelease>? releases,
    int? nextReleasesPage,
    int? lastReleasesPage,
    bool? loadingMoreReleases,
    String? error,
  }) {
    return AnimeDetailsState(
      status: status ?? this.status,
      details: details ?? this.details,
      releases: releases ?? this.releases,
      nextReleasesPage: nextReleasesPage ?? this.nextReleasesPage,
      lastReleasesPage: lastReleasesPage ?? this.lastReleasesPage,
      loadingMoreReleases: loadingMoreReleases ?? this.loadingMoreReleases,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    details,
    releases,
    nextReleasesPage,
    lastReleasesPage,
    loadingMoreReleases,
    error,
  ];
}
