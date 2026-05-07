import 'dart:async';

import 'package:better_player_enhanced/better_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:free_anime/core/di/service_locator.dart';
import 'package:free_anime/core/theme/app_theme.dart';
import 'package:free_anime/features/downloads/data/download_file_launcher.dart';
import 'package:free_anime/features/downloads/data/download_item.dart';
import 'package:free_anime/features/downloads/data/download_request.dart';
import 'package:free_anime/features/downloads/presentation/cubit/downloads_cubit.dart';
import 'package:free_anime/features/watch/data/watch_models.dart';
import 'package:free_anime/features/watch/presentation/cubit/watch_cubit.dart';
import 'package:free_anime/features/watch/presentation/player/watch_player_factories.dart';
import 'package:free_anime/features/watch_history/data/watch_history_item.dart';
import 'package:free_anime/features/watch_history/presentation/cubit/watch_history_cubit.dart';

class WatchPageExtra {
  const WatchPageExtra({
    this.episode = '',
    this.title = '',
    this.snapshot = '',
    this.duration = '',
    this.poster = '',
  });

  final String episode;
  final String title;
  final String snapshot;
  final String duration;
  final String poster;
}

class WatchPage extends StatefulWidget {
  const WatchPage({
    super.key,
    required this.animeSession,
    required this.episodeSession,
    this.extra = const WatchPageExtra(),
    this.preferredSourceUrl,
    this.fullscreenMode = false,
  });

  final String animeSession;
  final String episodeSession;
  final WatchPageExtra extra;
  final String? preferredSourceUrl;
  final bool fullscreenMode;

  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> {
  late final WatchCubit _watchCubit;
  late final WatchHistoryCubit _watchHistoryCubit;
  final _playerConfigurationFactory = const WatchPlayerConfigurationFactory();
  final _playerDataSourceFactory = const WatchPlayerDataSourceFactory();

  BetterPlayerController? _playerController;
  String? _loadedSourceUrl;
  String? _loadedEpisodeSession;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _lastPersistedSecond = -1;
  Duration? _pendingSeek;
  bool _isBuffering = false;
  bool _isPlaying = false;
  bool _navigatingToNext = false;
  bool _showDownloads = false;
  int _sourceLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _watchCubit = context.read<WatchCubit>();
    _watchHistoryCubit = context.read<WatchHistoryCubit>();
    _ensurePlayerController();
    _watchCubit.load(
      animeSession: widget.animeSession,
      episodeSession: widget.episodeSession,
      preferredSourceUrl: widget.preferredSourceUrl,
    );
  }

  @override
  void dispose() {
    unawaited(_persistProgress());
    _playerController?.dispose(forceDispose: true);
    super.dispose();
  }

  void _ensurePlayerController() {
    if (_playerController != null) return;
    final controller = BetterPlayerController(
      _playerConfigurationFactory.build(
        placeholder: buildWatchPlaceholder(widget.extra.snapshot),
        onEvent: _onPlayerEvent,
        errorBuilder: (context, errorMessage) => _PlayerErrorView(
          message: errorMessage ?? 'Playback failed.',
          onRetry: () => _playerController?.retryDataSource(),
        ),
        overflowMenuCustomItems: const [],
      ),
    );
    _playerController = controller;
  }

  Future<void> _loadSelectedSource(WatchState state, WatchSource source) async {
    _ensurePlayerController();
    if (!isValidWatchSourceUrl(source.url)) {
      _watchCubit.setPlayerError('Selected source is invalid.');
      return;
    }

    final generation = ++_sourceLoadGeneration;
    final episodeSession =
        state.currentRelease?.session ?? widget.episodeSession;
    final shouldResumeFromCurrentEpisode =
        _loadedEpisodeSession == episodeSession && _loadedSourceUrl != null;
    if (_loadedEpisodeSession == episodeSession &&
        _loadedSourceUrl == source.url) {
      return;
    }

    final headers = _headersForSource(source);
    final placeholder = buildWatchPlaceholder(
      state.currentRelease?.snapshot.isNotEmpty == true
          ? state.currentRelease!.snapshot
          : widget.extra.snapshot,
    );
    final dataSource = _playerDataSourceFactory.build(
      selectedSource: source,
      allSources: state.info?.sources ?? const <WatchSource>[],
      headers: headers,
      placeholder: placeholder,
    );

    _pendingSeek = shouldResumeFromCurrentEpisode
        ? _position
        : _resumePositionForEpisode(episodeSession);
    _loadedSourceUrl = source.url;
    _loadedEpisodeSession = episodeSession;
    _navigatingToNext = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _lastPersistedSecond = -1;
    _isBuffering = true;
    _isPlaying = false;
    if (mounted) setState(() {});

    await _playerController!.setupDataSource(dataSource);
    if (!mounted || generation != _sourceLoadGeneration) return;
  }

  Duration _resumePositionForEpisode(String episodeSession) {
    final match = _watchHistoryCubit.state.items
        .where((item) => item.episodeSession == episodeSession)
        .toList();
    if (match.isEmpty) return Duration.zero;
    final item = match.first;
    if (!item.canResume || item.positionMs <= 0) return Duration.zero;
    return Duration(milliseconds: item.positionMs);
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;
    _syncPlayerSnapshot();

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        final seek = _pendingSeek;
        _pendingSeek = null;
        if (seek != null && seek > Duration.zero) {
          unawaited(_playerController?.seekTo(seek) ?? Future.value());
        }
        break;
      case BetterPlayerEventType.progress:
      case BetterPlayerEventType.seekTo:
        final seconds = _position.inSeconds;
        if (seconds != _lastPersistedSecond &&
            seconds > 0 &&
            seconds % 5 == 0) {
          _lastPersistedSecond = seconds;
          unawaited(_persistProgress());
        }
        break;
      case BetterPlayerEventType.play:
        _isPlaying = true;
        _isBuffering = false;
        break;
      case BetterPlayerEventType.pause:
        _isPlaying = false;
        unawaited(_persistProgress());
        break;
      case BetterPlayerEventType.bufferingStart:
        _isBuffering = true;
        break;
      case BetterPlayerEventType.bufferingEnd:
        _isBuffering = false;
        break;
      case BetterPlayerEventType.finished:
        unawaited(_persistProgress(forceCompleted: true));
        final next = _watchCubit.state.nextRelease;
        if (!_navigatingToNext && next != null) {
          _navigatingToNext = true;
          unawaited(_goToEpisode(_watchCubit.state.currentIndex! + 1));
        }
        break;
      case BetterPlayerEventType.exception:
        final message =
            event.parameters?['exception']?.toString() ??
            event.parameters?['message']?.toString() ??
            'Playback failed.';
        _watchCubit.setPlayerError(message);
        _isBuffering = false;
        _isPlaying = false;
        break;
      default:
        break;
    }

    if (mounted) setState(() {});
  }

  void _syncPlayerSnapshot() {
    final value = _playerController?.videoPlayerController?.value;
    if (value == null) return;
    _position = value.position;
    _duration = value.duration ?? Duration.zero;
  }

  Future<void> _persistProgress({bool forceCompleted = false}) async {
    _syncPlayerSnapshot();
    final state = _watchCubit.state;
    final info = state.info;
    final currentRelease = state.currentRelease;
    final episodeSession = currentRelease?.session ?? widget.episodeSession;
    if (info == null || _duration <= Duration.zero) return;

    final rawProgress = forceCompleted
        ? 1.0
        : (_position.inMilliseconds / _duration.inMilliseconds);
    final progress = rawProgress.clamp(0.0, 1.0);

    await _watchHistoryCubit.saveProgress(
      WatchHistoryItem(
        animeSession: widget.animeSession,
        episodeSession: episodeSession,
        animeTitle: info.animeTitle.isEmpty
            ? widget.extra.title
            : info.animeTitle,
        episodeLabel:
            'Episode ${info.episode.isEmpty ? widget.extra.episode : info.episode}',
        poster: widget.extra.poster,
        snapshot: currentRelease?.snapshot ?? widget.extra.snapshot,
        positionMs: forceCompleted
            ? _duration.inMilliseconds
            : _position.inMilliseconds,
        durationMs: _duration.inMilliseconds,
        progress: progress,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _goToEpisode(int index) async {
    await _persistProgress();
    await _watchCubit.goToEpisode(index);
  }

  Map<String, String> _headersForSource(WatchSource source) {
    final embed = source.embed.trim();
    final parsedEmbed = Uri.tryParse(embed);
    final hasAbsoluteEmbed =
        parsedEmbed != null &&
        parsedEmbed.hasScheme &&
        parsedEmbed.host.isNotEmpty;
    final referer = hasAbsoluteEmbed ? embed : 'https://kwik.cx/';
    final origin = hasAbsoluteEmbed ? parsedEmbed.origin : 'https://kwik.cx';
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': referer,
      'Origin': origin,
      'Accept': '*/*',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<WatchCubit, WatchState>(
        listenWhen: (previous, current) =>
            previous.selectedSource?.url != current.selectedSource?.url ||
            previous.currentRelease?.session != current.currentRelease?.session,
        listener: (context, state) {
          final source = state.selectedSource;
          if (source != null) {
            unawaited(_loadSelectedSource(state, source));
          }
        },
        builder: (context, state) {
          if (state.status == WatchStatus.loading && state.info == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == WatchStatus.failure) {
            return _PageError(
              message: state.error ?? 'Failed to load episode.',
            );
          }

          final info = state.info;
          if (info == null) return const SizedBox.shrink();

          final episodeLabel = info.episode.isEmpty
              ? widget.extra.episode
              : info.episode;
          final currentRelease = state.currentRelease;

          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 32),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _playerController == null
                            ? const ColoredBox(
                                color: Color(0xFF111118),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : BetterPlayer(controller: _playerController!),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: IconButton.filled(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatusChip(
                      label: _isBuffering
                          ? 'Buffering'
                          : _isPlaying
                          ? 'Playing'
                          : 'Paused',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusChip(
                      label:
                          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ControlIconButton(
                    tooltip: 'Previous episode',
                    icon: Icons.skip_previous_rounded,
                    onPressed:
                        state.previousRelease == null || state.currentIndex == null
                        ? null
                        : () => unawaited(_goToEpisode(state.currentIndex! - 1)),
                  ),
                  const SizedBox(width: 8),
                  _ControlIconButton(
                    tooltip: 'Next episode',
                    icon: Icons.skip_next_rounded,
                    onPressed:
                        state.nextRelease == null || state.currentIndex == null
                        ? null
                        : () => unawaited(_goToEpisode(state.currentIndex! + 1)),
                  ),
                  const SizedBox(width: 8),
                  _ControlIconButton(
                    tooltip: 'Choose source',
                    icon: Icons.swap_horiz_rounded,
                    onPressed: () => _showSourceChooser(context, state),
                  ),
                  const SizedBox(width: 8),
                  _ControlIconButton(
                    tooltip: _showDownloads ? 'Hide downloads' : 'Show downloads',
                    icon: _showDownloads
                        ? Icons.download_done_rounded
                        : Icons.download_rounded,
                    onPressed: () => _toggleDownloadsPanel(state),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                info.animeTitle.isEmpty ? widget.extra.title : info.animeTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Episode $episodeLabel',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.primarySoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(label: 'Sources ${info.sources.length}'),
                  _InfoPill(label: 'Downloads ${info.downloads.length}'),
                  if (currentRelease?.duration.trim().isNotEmpty == true)
                    _InfoPill(label: currentRelease!.duration),
                  if (currentRelease?.audio.trim().isNotEmpty == true)
                    _InfoPill(label: currentRelease!.audio),
                ],
              ),
              if (state.error != null && state.error!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  state.error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 18),
              BlocBuilder<DownloadsCubit, DownloadsState>(
                bloc: getIt<DownloadsCubit>(),
                builder: (context, downloadsState) {
                  final offlineItem = downloadsState.completedDownloadFor(
                    widget.animeSession,
                    widget.episodeSession,
                  );
                  if (offlineItem == null) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _OfflineDownloadBanner(
                      label: offlineItem.displayEpisodeLabel,
                      onOpen: () =>
                          _openDownloadedEpisode(context, offlineItem.filePath),
                    ),
                  );
                },
              ),
              Text(
                'Choose source',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: info.sources
                    .where((source) => isValidWatchSourceUrl(source.url))
                    .map(
                      (source) => ChoiceChip(
                        label: Text(source.label),
                        selected: state.selectedSource?.url == source.url,
                        onSelected: (_) => _watchCubit.selectSource(source),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              if (_showDownloads) ...[
                const SizedBox(height: 14),
                ...(state.info?.downloads ?? const <WatchDownload>[]).map(
                  (download) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DownloadOptionCard(
                      title: download.label,
                      subtitle:
                          'Save episode $episodeLabel for offline viewing',
                      onTap: () => _enqueueDownload(context, info, download),
                    ),
                  ),
                ),
                if ((state.info?.downloads ?? const <WatchDownload>[]).isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No downloads available for this episode yet.'),
                  ),
              ],
              const SizedBox(height: 22),
              if (currentRelease != null)
                _EpisodeInfoCard(
                  title: currentRelease.title.isEmpty
                      ? 'Episode $episodeLabel'
                      : currentRelease.title,
                  subtitle: [
                    if (currentRelease.createdAt.isNotEmpty)
                      currentRelease.createdAt,
                    if (currentRelease.duration.isNotEmpty)
                      currentRelease.duration,
                  ].join(' • '),
                  description:
                      'Source provider: ${info.provider.isEmpty ? 'unknown' : info.provider}. Better Player now owns transport, seek, and retry behaviour while the app keeps episode, source, and download controls outside the player.',
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _enqueueDownload(
    BuildContext context,
    WatchInfo info,
    WatchDownload download,
  ) async {
    String downloadUrl;
    try {
      if (download.download.trim().isNotEmpty) {
        downloadUrl = download.download.trim();
      } else {
        downloadUrl = await _watchCubit.resolveDownloadUrl(download);
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
      downloadPage: download.downloadPage,
    );

    final filename = _filenameFor(info, download, downloadUrl);
    getIt<DownloadsCubit>().enqueue(
      DownloadItem(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        animeSession: widget.animeSession,
        episodeSession: widget.episodeSession,
        animeTitle: info.animeTitle.isEmpty
            ? widget.extra.title
            : info.animeTitle,
        animePoster: widget.extra.poster,
        episode: info.episode,
        episodeLabel:
            'Episode ${info.episode.isEmpty ? widget.extra.episode : info.episode}',
        episodeSnapshot:
            _watchCubit.state.currentRelease?.snapshot ?? widget.extra.snapshot,
        resolution: download.resolution,
        fansub: download.fansub,
        isDub: download.isDub,
        url: request.primaryUrl,
        candidateUrls: request.candidateUrls,
        downloadPage: download.downloadPage,
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

  Future<void> _toggleDownloadsPanel(WatchState state) async {
    if (state.loadingDownloads) return;
    if (state.info?.downloads.isEmpty ?? true) {
      await _watchCubit.loadDownloads();
    }
    if (!mounted) return;
    setState(() => _showDownloads = !_showDownloads);
  }

  Future<void> _showSourceChooser(
    BuildContext context,
    WatchState state,
  ) async {
    final sources = state.info?.sources
            .where((source) => isValidWatchSourceUrl(source.url))
            .toList() ??
        const <WatchSource>[];
    if (sources.isEmpty) return;

    final selectedSource = await showModalBottomSheet<WatchSource>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: sources.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final source = sources[index];
            return ListTile(
              title: Text(source.label),
              trailing: state.selectedSource?.url == source.url
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.of(context).pop(source),
            );
          },
        ),
      ),
    );
    if (selectedSource == null) return;
    _watchCubit.selectSource(selectedSource);
  }

  String _filenameFor(WatchInfo info, WatchDownload download, String url) {
    final uri = Uri.tryParse(url);
    final fileParam = uri?.queryParameters['file'];
    if (fileParam != null && fileParam.trim().isNotEmpty) {
      return fileParam.trim();
    }

    final title = info.animeTitle
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final episode = info.episode.isEmpty ? widget.extra.episode : info.episode;
    final resolution = download.resolution.isEmpty
        ? ''
        : '_${download.resolution}p';
    return '${title}_Episode_$episode$resolution.mp4';
  }

  Future<void> _openDownloadedEpisode(
    BuildContext context,
    String filePath,
  ) async {
    final message = await DownloadFileLauncher.openVideo(filePath);
    if (!context.mounted || message == null) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDuration(Duration value) {
    if (value <= Duration.zero) return '--:--';
    final totalSeconds = value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: FilledButton.tonal(
          onPressed: onPressed,
          child: Icon(icon),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _DownloadOptionCard extends StatelessWidget {
  const _DownloadOptionCard({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.download_for_offline_rounded,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _OfflineDownloadBanner extends StatelessWidget {
  const _OfflineDownloadBanner({required this.label, required this.onOpen});

  final String label;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.statusComplete.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.statusComplete.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.offline_pin_rounded, color: AppTheme.statusComplete),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label is already offline',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Open the downloaded file instantly, or keep using the online sources below.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.tonal(onPressed: onOpen, child: const Text('Open')),
        ],
      ),
    );
  }
}

class _EpisodeInfoCard extends StatelessWidget {
  const _EpisodeInfoCard({
    required this.title,
    required this.subtitle,
    required this.description,
  });

  final String title;
  final String subtitle;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PlayerErrorView extends StatelessWidget {
  const _PlayerErrorView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF111118),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PageError extends StatelessWidget {
  const _PageError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
