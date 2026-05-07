import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:free_anime/core/di/service_locator.dart';
import 'package:free_anime/core/theme/app_theme.dart';
import 'package:free_anime/features/downloads/data/download_file_launcher.dart';
import 'package:free_anime/features/downloads/data/download_item.dart';
import 'package:free_anime/features/downloads/presentation/cubit/downloads_cubit.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: BlocBuilder<DownloadsCubit, DownloadsState>(
        bloc: getIt<DownloadsCubit>(),
        builder: (context, state) {
          if (state.items.isEmpty) {
            return const _EmptyDownloadsView();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _DownloadsHero(state: state),
              const SizedBox(height: 18),
              Text(
                'Series & Movies',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Every episode stays grouped under its anime so offline viewing feels like a library, not a transfer log.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ...state.animeGroups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _AnimeGroupCard(group: group),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DownloadsHero extends StatelessWidget {
  const _DownloadsHero({required this.state});

  final DownloadsState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241726), Color(0xFF131820)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusLarge),
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Offline Library',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '${state.activeCount} active downloads, ${state.completedCount} ready to watch.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  label: 'Titles',
                  value: '${state.animeGroups.length}',
                  tone: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricPill(
                  label: 'Downloading',
                  value: '${state.activeCount}',
                  tone: AppTheme.statusActive,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricPill(
                  label: 'Completed',
                  value: '${state.completedCount}',
                  tone: AppTheme.statusComplete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusMedium),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AnimeGroupCard extends StatefulWidget {
  const _AnimeGroupCard({required this.group});

  final DownloadAnimeGroup group;

  @override
  State<_AnimeGroupCard> createState() => _AnimeGroupCardState();
}

class _AnimeGroupCardState extends State<_AnimeGroupCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded =
        widget.group.hasActiveDownloads || widget.group.items.length <= 3;
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusLarge),
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.cardRadiusLarge),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GroupArtwork(group: group),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _GroupBadge(
                              label: '${group.completedCount} offline',
                              color: AppTheme.statusComplete,
                            ),
                            if (group.activeCount > 0)
                              _GroupBadge(
                                label: '${group.activeCount} active',
                                color: AppTheme.statusActive,
                              ),
                            if (group.pausedCount > 0)
                              _GroupBadge(
                                label: '${group.pausedCount} paused',
                                color: AppTheme.statusPaused,
                              ),
                            if (group.failedCount > 0)
                              _GroupBadge(
                                label: '${group.failedCount} failed',
                                color: AppTheme.statusFailed,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 8),
                  ...group.sortedEpisodes.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _EpisodeDownloadRow(item: item),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupArtwork extends StatelessWidget {
  const _GroupArtwork({required this.group});

  final DownloadAnimeGroup group;

  @override
  Widget build(BuildContext context) {
    final poster = group.poster.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.cardRadiusMedium),
      child: SizedBox(
        width: 76,
        height: 104,
        child: poster.isEmpty
            ? Container(
                color: AppTheme.elevatedSurface,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.movie_creation_outlined,
                  color: Colors.white54,
                ),
              )
            : CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
      ),
    );
  }
}

class _GroupBadge extends StatelessWidget {
  const _GroupBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _EpisodeDownloadRow extends StatelessWidget {
  const _EpisodeDownloadRow({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (item.resolution.trim().isNotEmpty) '${item.resolution}p',
      item.isDub ? 'Dub' : 'Sub',
      if (item.fansub.trim().isNotEmpty) item.fansub.trim(),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusMedium),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayEpisodeLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitleParts.join(' • '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _EpisodeStatusBadge(status: item.status),
            ],
          ),
          if (item.isActive) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: item.progress <= 0 ? null : item.progress,
            ),
            const SizedBox(height: 6),
            Text(_progressLabel, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (item.error.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.error.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.statusFailed),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (item.hasOfflineFile)
                TextButton.icon(
                  onPressed: () => _openFile(context),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('Open'),
                ),
              if (item.status == DownloadStatus.downloading)
                TextButton.icon(
                  onPressed: () => getIt<DownloadsCubit>().pause(item.id),
                  icon: const Icon(Icons.pause_circle_outline_rounded),
                  label: const Text('Pause'),
                ),
              if (item.canResume)
                TextButton.icon(
                  onPressed: () => getIt<DownloadsCubit>().resume(item.id),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('Resume'),
                ),
              if (item.status == DownloadStatus.failed)
                TextButton.icon(
                  onPressed: () => getIt<DownloadsCubit>().retry(item.id),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              if (item.isActive)
                TextButton.icon(
                  onPressed: () => getIt<DownloadsCubit>().cancel(item.id),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Cancel'),
                ),
              TextButton.icon(
                onPressed: () => getIt<DownloadsCubit>().remove(item.id),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _progressLabel {
    final bytesLabel = item.receivedBytes > 0
        ? item.totalBytes > 0
              ? '${_formatBytes(item.receivedBytes)} / ${_formatBytes(item.totalBytes)}'
              : _formatBytes(item.receivedBytes)
        : item.status.name;
    final detailParts = [
      if (item.speedBytesPerSecond > 0)
        '${_formatBytes(item.speedBytesPerSecond.round())}/s',
      if (item.etaSeconds > 0) 'ETA ${_formatEta(item.etaSeconds)}',
    ];
    if (detailParts.isEmpty) return bytesLabel;
    return '$bytesLabel • ${detailParts.join(' • ')}';
  }

  Future<void> _openFile(BuildContext context) async {
    final message = await DownloadFileLauncher.openVideo(item.filePath);
    if (!context.mounted || message == null) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  String _formatEta(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    if (minutes <= 0) return '${remainder}s';
    return '${minutes}m ${remainder}s';
  }
}

class _EpisodeStatusBadge extends StatelessWidget {
  const _EpisodeStatusBadge({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      DownloadStatus.completed => AppTheme.statusComplete,
      DownloadStatus.paused => AppTheme.statusPaused,
      DownloadStatus.failed => AppTheme.statusFailed,
      DownloadStatus.cancelled => AppTheme.statusMuted,
      DownloadStatus.downloading => AppTheme.statusActive,
      DownloadStatus.queued => AppTheme.primarySoft,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(status.name, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _EmptyDownloadsView extends StatelessWidget {
  const _EmptyDownloadsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(AppTheme.cardRadiusLarge),
            border: Border.all(color: AppTheme.borderStrong),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.download_for_offline_outlined,
                size: 42,
                color: AppTheme.primarySoft,
              ),
              const SizedBox(height: 14),
              Text(
                'No offline episodes yet',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Start a download from any episode and it will appear here grouped under its anime title.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
