import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_anime/core/di/service_locator.dart';
import 'package:free_anime/features/downloads/data/download_item.dart';
import 'package:free_anime/features/downloads/data/downloads_repository.dart';
import 'package:free_anime/features/downloads/presentation/cubit/downloads_cubit.dart';
import 'package:free_anime/features/downloads/presentation/view/downloads_page.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Box box;
  late _TestDownloadsCubit cubit;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('free-anime-test');
    Hive.init(tempDir.path);
    box = await Hive.openBox('downloads_test');
    final repository = DownloadsRepository(box: box, dio: Dio());
    cubit = _TestDownloadsCubit(repository: repository);
    await getIt.reset();
    getIt.registerSingleton<DownloadsCubit>(cubit);
  });

  tearDown(() async {
    await getIt.reset();
    await box.close();
    await Hive.deleteBoxFromDisk('downloads_test');
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('renders grouped anime library instead of flat tabs', (
    tester,
  ) async {
    cubit.seed([
      _item(
        id: '1',
        animeSession: 'anime-a',
        episodeSession: 'ep-1',
        animeTitle: 'Jujutsu Kaisen',
        episode: '1',
        status: DownloadStatus.completed,
        filePath: '/downloads/jjk-1.mp4',
      ),
      _item(
        id: '2',
        animeSession: 'anime-a',
        episodeSession: 'ep-2',
        animeTitle: 'Jujutsu Kaisen',
        episode: '2',
        status: DownloadStatus.downloading,
      ),
    ]);

    await tester.pumpWidget(const MaterialApp(home: DownloadsPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Offline Library'), findsOneWidget);
    expect(find.text('Series & Movies'), findsOneWidget);
    expect(find.text('Jujutsu Kaisen'), findsOneWidget);
    expect(find.text('Episode 1'), findsOneWidget);
    expect(find.text('Queue'), findsNothing);
    expect(find.text('History'), findsNothing);
  });
}

class _TestDownloadsCubit extends DownloadsCubit {
  _TestDownloadsCubit({required super.repository});

  void seed(List<DownloadItem> items) {
    emit(DownloadsState(items: items));
  }
}

DownloadItem _item({
  required String id,
  required String animeSession,
  required String episodeSession,
  required String animeTitle,
  required String episode,
  required DownloadStatus status,
  String filePath = '',
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
    createdAt: DateTime.parse('2026-05-07T00:00:00Z'),
    filePath: filePath,
    status: status,
  );
}
