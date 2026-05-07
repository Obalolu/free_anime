import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:free_anime/core/di/service_locator.dart';
import 'package:free_anime/features/downloads/data/download_file_launcher.dart';
import 'package:free_anime/features/downloads/data/download_item.dart';
import 'package:free_anime/features/downloads/data/download_request.dart';
import 'package:free_anime/features/downloads/presentation/cubit/downloads_cubit.dart';
import 'package:free_anime/features/watch/data/watch_models.dart';
import 'package:free_anime/features/watch/data/watch_repository.dart';
import 'package:free_anime/features/watch/presentation/cubit/watch_cubit.dart';
import 'package:free_anime/features/watch/presentation/player/watch_player_factories.dart';
import 'package:free_anime/features/watch/presentation/view/watch_page.dart';

final class PlaybackLauncher {
  const PlaybackLauncher._();

  static Future<void> launchFullscreen({
    required BuildContext context,
    required String animeSession,
    required String episodeSession,
    required WatchPageExtra extra,
    String? preferredSourceUrl,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Playback',
      barrierColor: Colors.black,
      pageBuilder: (context, _, __) {
        return BlocProvider<WatchCubit>(
          create: (_) => getIt<WatchCubit>(),
          child: WatchPage(
            animeSession: animeSession,
            episodeSession: episodeSession,
            extra: extra,
            preferredSourceUrl: preferredSourceUrl,
            fullscreenMode: true,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Future<void> chooseSourceAndPlay({
    required BuildContext context,
    required String animeSession,
    required String episodeSession,
    required WatchPageExtra extra,
  }) async {
    WatchInfo info;
    try {
      info = await getIt<WatchRepository>().fetchWatchInfo(
        animeSession: animeSession,
        episodeSession: episodeSession,
        includeDownloads: false,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load episode sources: $error')),
      );
      return;
    }
    if (!context.mounted) return;
    final sources =
        info.sources
            .where((source) => isValidWatchSourceUrl(source.url))
            .toList()
          ..sort(
            (left, right) =>
                right.resolutionValue.compareTo(left.resolutionValue),
          );
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No playable sources found for this episode.'),
        ),
      );
      return;
    }

    final selectedSource = await showDialog<WatchSource>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Choose source'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: sources.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final source = sources[index];
                return ListTile(
                  title: Text(source.label),
                  subtitle: Text(source.url),
                  onTap: () => Navigator.of(dialogContext).pop(source),
                );
              },
            ),
          ),
        );
      },
    );

    if (!context.mounted || selectedSource == null) return;
    await launchFullscreen(
      context: context,
      animeSession: animeSession,
      episodeSession: episodeSession,
      extra: extra,
      preferredSourceUrl: selectedSource.url,
    );
  }

  static Future<void> showDownloadOptions({
    required BuildContext context,
    required String animeSession,
    required String episodeSession,
    required String animeTitle,
    required String animePoster,
    required String episodeLabel,
    required String snapshot,
  }) async {
    final info = await getIt<WatchRepository>().fetchWatchInfo(
      animeSession: animeSession,
      episodeSession: episodeSession,
      includeDownloads: true,
    );
    if (!context.mounted) return;
    final downloads = info.downloads;
    if (downloads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No download sources found for this episode.'),
        ),
      );
      return;
    }

    final selectedDownload = await showDialog<WatchDownload>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Choose download source'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: downloads.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final download = downloads[index];
                return ListTile(
                  title: Text(download.label),
                  onTap: () => Navigator.of(dialogContext).pop(download),
                );
              },
            ),
          ),
        );
      },
    );

    if (!context.mounted || selectedDownload == null) return;

    String downloadUrl;
    try {
      if (selectedDownload.download.trim().isNotEmpty) {
        downloadUrl = selectedDownload.download.trim();
      } else {
        downloadUrl = await getIt<WatchRepository>().resolveDownloadUrl(
          selectedDownload.pahe,
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resolve download: $error')),
      );
      return;
    }

    final request = const DownloadUrlResolver().resolve(
      url: downloadUrl,
      downloadPage: selectedDownload.downloadPage,
    );
    final filename = _filenameFor(
      animeTitle: animeTitle,
      episodeLabel: info.episode.isEmpty ? episodeLabel : info.episode,
      resolution: selectedDownload.resolution,
      url: downloadUrl,
    );

    getIt<DownloadsCubit>().enqueue(
      DownloadItem(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        animeSession: animeSession,
        episodeSession: episodeSession,
        animeTitle: animeTitle,
        animePoster: animePoster,
        episode: info.episode,
        episodeLabel:
            'Episode ${info.episode.isEmpty ? episodeLabel : info.episode}',
        episodeSnapshot: snapshot,
        resolution: selectedDownload.resolution,
        fansub: selectedDownload.fansub,
        isDub: selectedDownload.isDub,
        url: request.primaryUrl,
        candidateUrls: request.candidateUrls,
        downloadPage: selectedDownload.downloadPage,
        referer: request.referer,
        origin: request.origin,
        filename: filename,
        createdAt: DateTime.now(),
      ),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added to downloads queue.')));
  }

  static Future<void> handleEpisodeDownloadAction({
    required BuildContext context,
    required String animeSession,
    required String episodeSession,
    required String animeTitle,
    required String animePoster,
    required String episodeLabel,
    required String snapshot,
    required DownloadItem? downloadItem,
  }) async {
    final downloadsCubit = getIt<DownloadsCubit>();
    if (downloadItem == null ||
        downloadItem.status == DownloadStatus.cancelled) {
      await showDownloadOptions(
        context: context,
        animeSession: animeSession,
        episodeSession: episodeSession,
        animeTitle: animeTitle,
        animePoster: animePoster,
        episodeLabel: episodeLabel,
        snapshot: snapshot,
      );
      return;
    }

    switch (downloadItem.status) {
      case DownloadStatus.downloading:
        await downloadsCubit.pause(downloadItem.id);
      case DownloadStatus.paused:
        await downloadsCubit.resume(downloadItem.id);
      case DownloadStatus.failed:
        await downloadsCubit.retry(downloadItem.id);
      case DownloadStatus.completed:
        final message = await DownloadFileLauncher.openVideo(
          downloadItem.filePath,
        );
        if (context.mounted && message != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      case DownloadStatus.queued:
        await downloadsCubit.cancel(downloadItem.id);
      case DownloadStatus.cancelled:
        break;
    }
  }

  static String _filenameFor({
    required String animeTitle,
    required String episodeLabel,
    required String resolution,
    required String url,
  }) {
    final uri = Uri.tryParse(url);
    final fileParam = uri?.queryParameters['file'];
    if (fileParam != null && fileParam.trim().isNotEmpty) {
      return fileParam.trim();
    }

    final normalizedTitle = animeTitle
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final normalizedEpisode = episodeLabel.replaceAll(
      RegExp(r'[^0-9A-Za-z]+'),
      '_',
    );
    final resolutionSuffix = resolution.trim().isEmpty
        ? ''
        : '_${resolution.trim()}p';
    return '${normalizedTitle}_${normalizedEpisode}$resolutionSuffix.mp4';
  }
}
