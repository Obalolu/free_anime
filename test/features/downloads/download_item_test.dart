import 'package:flutter_test/flutter_test.dart';
import 'package:free_anime/features/downloads/data/download_item.dart';

void main() {
  test('DownloadItem serializes and deserializes new anime metadata', () {
    final item = DownloadItem(
      id: '1',
      animeSession: 'anime-1',
      episodeSession: 'episode-7',
      animeTitle: 'Fullmetal Alchemist',
      animePoster: 'https://image/poster.jpg',
      episode: '7',
      episodeLabel: 'Episode 7',
      episodeSnapshot: 'https://image/snapshot.jpg',
      resolution: '1080',
      fansub: 'SubPlease',
      isDub: false,
      url: 'https://cdn/video.mp4',
      filename: 'episode-7.mp4',
      createdAt: DateTime.parse('2026-05-07T00:00:00Z'),
      filePath: '/downloads/episode-7.mp4',
      status: DownloadStatus.completed,
    );

    final restored = DownloadItem.fromJson(item.toJson());

    expect(restored.animeSession, 'anime-1');
    expect(restored.episodeSession, 'episode-7');
    expect(restored.animePoster, 'https://image/poster.jpg');
    expect(restored.episodeLabel, 'Episode 7');
    expect(restored.episodeSnapshot, 'https://image/snapshot.jpg');
    expect(restored.hasOfflineFile, isTrue);
  });

  test('DownloadItem keeps backward compatibility for legacy records', () {
    final restored = DownloadItem.fromJson({
      'id': 'legacy',
      'animeTitle': 'Bleach',
      'episode': '12',
      'resolution': '720',
      'fansub': '',
      'isDub': false,
      'url': 'https://cdn/video.mp4',
      'filename': 'bleach-12.mp4',
      'createdAt': '2026-05-07T00:00:00Z',
      'status': 'completed',
    });

    expect(restored.animeSession, isEmpty);
    expect(restored.episodeSession, isEmpty);
    expect(restored.displayEpisodeLabel, 'Episode 12');
    expect(restored.hasOfflineFile, isFalse);
  });
}
