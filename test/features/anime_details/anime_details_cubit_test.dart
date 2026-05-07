import 'package:flutter_test/flutter_test.dart';
import 'package:free_anime/features/anime_details/data/anime_details_models.dart';
import 'package:free_anime/features/anime_details/data/anime_details_repository.dart';
import 'package:free_anime/features/anime_details/presentation/cubit/anime_details_cubit.dart';

void main() {
  group('AnimeDetailsCubit pagination', () {
    test('eager-loads up to five pages then exposes continuation', () async {
      final repository = _FakeAnimeDetailsRepository(lastPage: 7);
      final cubit = AnimeDetailsCubit(repository: repository);

      await cubit.load('anime-session');

      expect(cubit.state.status, AnimeDetailsStatus.success);
      expect(cubit.state.releases.length, 5);
      expect(cubit.state.nextReleasesPage, 6);
      expect(cubit.state.lastReleasesPage, 7);
      expect(cubit.state.hasMoreReleases, isTrue);
      expect(repository.pageRequests, [1, 2, 3, 4, 5]);
    });

    test('loadMoreReleases appends next page items', () async {
      final repository = _FakeAnimeDetailsRepository(lastPage: 7);
      final cubit = AnimeDetailsCubit(repository: repository);

      await cubit.load('anime-session');
      await cubit.loadMoreReleases('anime-session');

      expect(cubit.state.releases.length, 6);
      expect(cubit.state.nextReleasesPage, 7);
      expect(cubit.state.lastReleasesPage, 7);
      expect(repository.pageRequests, [1, 2, 3, 4, 5, 6]);
    });

    test('loads all pages when lastPage is at threshold or lower', () async {
      final repository = _FakeAnimeDetailsRepository(lastPage: 3);
      final cubit = AnimeDetailsCubit(repository: repository);

      await cubit.load('anime-session');

      expect(cubit.state.releases.length, 3);
      expect(cubit.state.nextReleasesPage, 4);
      expect(cubit.state.lastReleasesPage, 3);
      expect(cubit.state.hasMoreReleases, isFalse);
      expect(repository.pageRequests, [1, 2, 3]);
    });
  });
}

final class _FakeAnimeDetailsRepository implements AnimeDetailsRepository {
  _FakeAnimeDetailsRepository({required this.lastPage});

  final int lastPage;
  final List<int> pageRequests = <int>[];

  @override
  Future<AnimeDetails> fetchDetails(String session) async {
    return AnimeDetails.fromJson(const {'title': 'Test anime'});
  }

  @override
  Future<List<AnimeEpisodeRelease>> fetchReleases(String session) async {
    return <AnimeEpisodeRelease>[];
  }

  @override
  Future<AnimeReleasesPage> fetchReleasesPage(
    String session, {
    required int page,
  }) async {
    pageRequests.add(page);
    return AnimeReleasesPage(
      releases: <AnimeEpisodeRelease>[_releaseFor(page)],
      currentPage: page,
      lastPage: lastPage,
    );
  }

  AnimeEpisodeRelease _releaseFor(int page) {
    return AnimeEpisodeRelease.fromJson({
      'id': 'release-$page',
      'episode': '$page',
      'episode2': '$page',
      'title': 'Episode $page',
      'snapshot': '',
      'audio': 'SUB',
      'duration': '24m',
      'session': 'ep-$page',
      'created_at': '2026-05-07',
    });
  }
}
