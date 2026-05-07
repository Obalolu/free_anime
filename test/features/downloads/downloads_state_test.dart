import 'package:flutter_test/flutter_test.dart';
import 'package:free_anime/features/downloads/data/download_item.dart';
import 'package:free_anime/features/downloads/presentation/cubit/downloads_cubit.dart';

void main() {
  group('DownloadsState', () {
    test('groups episodes by anime session and reports rollups', () {
      final state = DownloadsState(
        items: [
          _item(
            id: 'a1',
            animeSession: 'anime-a',
            episodeSession: 'ep-1',
            animeTitle: 'Attack on Titan',
            episode: '1',
            status: DownloadStatus.completed,
            filePath: '/downloads/aot-1.mp4',
          ),
          _item(
            id: 'a2',
            animeSession: 'anime-a',
            episodeSession: 'ep-2',
            animeTitle: 'Attack on Titan',
            episode: '2',
            status: DownloadStatus.downloading,
          ),
          _item(
            id: 'b1',
            animeSession: 'anime-b',
            episodeSession: 'ep-4',
            animeTitle: 'Death Note',
            episode: '4',
            status: DownloadStatus.failed,
          ),
        ],
      );

      expect(state.animeGroups, hasLength(2));
      expect(state.animeGroups.first.title, 'Attack on Titan');
      expect(state.animeGroups.first.completedCount, 1);
      expect(state.animeGroups.first.activeCount, 1);
      expect(state.animeGroups.first.sortedEpisodes.first.episode, '1');
    });

    test('finds latest and completed downloads per episode', () {
      final state = DownloadsState(
        items: [
          _item(
            id: 'old',
            animeSession: 'anime-a',
            episodeSession: 'ep-9',
            animeTitle: 'Solo Leveling',
            episode: '9',
            status: DownloadStatus.failed,
            createdAt: DateTime.parse('2026-05-07T00:00:00Z'),
          ),
          _item(
            id: 'new',
            animeSession: 'anime-a',
            episodeSession: 'ep-9',
            animeTitle: 'Solo Leveling',
            episode: '9',
            status: DownloadStatus.completed,
            filePath: '/downloads/solo-9.mp4',
            createdAt: DateTime.parse('2026-05-07T01:00:00Z'),
          ),
        ],
      );

      expect(state.latestForEpisode('anime-a', 'ep-9')?.id, 'new');
      expect(
        state.completedDownloadFor('anime-a', 'ep-9')?.filePath,
        '/downloads/solo-9.mp4',
      );
    });
  });
}

DownloadItem _item({
  required String id,
  required String animeSession,
  required String episodeSession,
  required String animeTitle,
  required String episode,
  required DownloadStatus status,
  String filePath = '',
  DateTime? createdAt,
}) {
  return DownloadItem(
    id: id,
    animeSession: animeSession,
    episodeSession: episodeSession,
    animeTitle: animeTitle,
    animePoster: '',
    episode: episode,
    episodeLabel: 'Episode $episode',
    episodeSnapshot: '',
    resolution: '1080',
    fansub: '',
    isDub: false,
    url: 'https://cdn/$id.mp4',
    filename: '$id.mp4',
    createdAt: createdAt ?? DateTime.parse('2026-05-07T00:00:00Z'),
    filePath: filePath,
    status: status,
  );
}
