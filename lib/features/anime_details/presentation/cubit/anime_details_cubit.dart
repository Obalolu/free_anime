import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/anime_details_models.dart';
import '../../data/anime_details_repository.dart';

part 'anime_details_state.dart';

class AnimeDetailsCubit extends Cubit<AnimeDetailsState> {
  static const int _eagerReleasePagesThreshold = 5;

  AnimeDetailsCubit({required AnimeDetailsRepository repository})
    : _repository = repository,
      super(const AnimeDetailsState());

  final AnimeDetailsRepository _repository;

  Future<void> load(String session) async {
    emit(state.copyWith(status: AnimeDetailsStatus.loading, error: null));
    try {
      final details = await _repository.fetchDetails(session);
      final releasesResult = await _fetchInitialReleases(session);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AnimeDetailsStatus.success,
          details: details,
          releases: releasesResult.releases,
          nextReleasesPage: releasesResult.nextPage,
          lastReleasesPage: releasesResult.lastPage,
          loadingMoreReleases: false,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AnimeDetailsStatus.failure,
          error: error.toString(),
        ),
      );
    }
  }

  Future<void> loadMoreReleases(String session) async {
    if (state.loadingMoreReleases || !state.hasMoreReleases) return;

    emit(state.copyWith(loadingMoreReleases: true, error: null));
    try {
      final pageData = await _repository.fetchReleasesPage(
        session,
        page: state.nextReleasesPage,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          releases: _deduplicateBySession([...state.releases, ...pageData.releases]),
          nextReleasesPage: pageData.currentPage + 1,
          lastReleasesPage: pageData.lastPage,
          loadingMoreReleases: false,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(loadingMoreReleases: false));
    }
  }

  Future<_InitialReleasesResult> _fetchInitialReleases(
    String session,
  ) async {
    try {
      final firstPage = await _repository.fetchReleasesPage(session, page: 1);
      var nextPage = firstPage.currentPage + 1;
      final releases = <AnimeEpisodeRelease>[...firstPage.releases];

      final maxEagerPage = firstPage.lastPage < _eagerReleasePagesThreshold
          ? firstPage.lastPage
          : _eagerReleasePagesThreshold;
      while (nextPage <= maxEagerPage) {
        final pageData = await _repository.fetchReleasesPage(
          session,
          page: nextPage,
        );
        releases.addAll(pageData.releases);
        nextPage = pageData.currentPage + 1;
      }

      return _InitialReleasesResult(
        releases: _deduplicateBySession(releases),
        nextPage: nextPage,
        lastPage: firstPage.lastPage,
      );
    } catch (_) {
      return const _InitialReleasesResult(
        releases: <AnimeEpisodeRelease>[],
        nextPage: 1,
        lastPage: 1,
      );
    }
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

final class _InitialReleasesResult {
  const _InitialReleasesResult({
    required this.releases,
    required this.nextPage,
    required this.lastPage,
  });

  final List<AnimeEpisodeRelease> releases;
  final int nextPage;
  final int lastPage;
}
