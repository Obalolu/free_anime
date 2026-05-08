import 'dart:async';

import 'package:better_player_enhanced/better_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import 'package:free_anime/core/di/service_locator.dart';
import 'package:free_anime/features/downloads/data/download_file_launcher.dart';
import 'package:free_anime/features/downloads/data/download_item.dart';
import 'package:free_anime/features/downloads/data/download_request.dart';
import 'package:free_anime/features/downloads/presentation/cubit/downloads_cubit.dart';
import 'package:free_anime/features/watch/data/watch_models.dart';
import 'package:free_anime/features/watch/presentation/cubit/watch_cubit.dart';
import 'package:free_anime/features/watch/presentation/player/controls/anime_player_material_controls.dart';
import 'package:free_anime/features/watch/presentation/player/watch_player_factories.dart';
import 'package:free_anime/features/watch/presentation/view/watch_page.dart';
import 'package:free_anime/features/watch_history/data/watch_history_item.dart';
import 'package:free_anime/features/watch_history/presentation/cubit/watch_history_cubit.dart';

class FullscreenPlayerPage extends StatefulWidget {
  const FullscreenPlayerPage({
    super.key,
    required this.animeSession,
    required this.episodeSession,
    this.extra = const WatchPageExtra(),
    this.preferredSourceUrl,
  });

  final String animeSession;
  final String episodeSession;
  final WatchPageExtra extra;
  final String? preferredSourceUrl;

  @override
  State<FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<FullscreenPlayerPage> {
  late final WatchCubit _watchCubit;
  late final WatchHistoryCubit _watchHistoryCubit;
  final _playerConfigurationFactory = const WatchPlayerConfigurationFactory();
  final _playerDataSourceFactory = const WatchPlayerDataSourceFactory();

  BetterPlayerController? _playerController;
  String? _loadedSourceUrl;
  String? _loadedEpisodeSession;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration? _pendingSeek;
  int _lastPersistedSecond = -1;
  int _sourceLoadGeneration = 0;
  bool _navigatingToNext = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _watchCubit = context.read<WatchCubit>();
    _watchHistoryCubit = context.read<WatchHistoryCubit>();
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    _ensurePlayerController();
    _watchCubit.load(
      animeSession: widget.animeSession,
      episodeSession: widget.episodeSession,
      preferredSourceUrl: widget.preferredSourceUrl,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_persistProgress());
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    _playerController?.dispose(forceDispose: true);
    super.dispose();
  }

  void _ensurePlayerController() {
    if (_playerController != null) return;
    _playerController = BetterPlayerController(
      _playerConfigurationFactory.build(
        placeholder: buildWatchPlaceholder(widget.extra.snapshot),
        onEvent: _onPlayerEvent,
        errorBuilder: (context, errorMessage) => _PlayerErrorView(
          message: errorMessage ?? 'Playback failed.',
          onRetry: () => _playerController?.retryDataSource(),
        ),
        customControlsBuilder: (controller, onPlayerVisibilityChanged) {
          return AnimePlayerMaterialControls(
            onControlsVisibilityChanged: onPlayerVisibilityChanged,
            controlsConfiguration: controller.betterPlayerControlsConfiguration,
            onClose: () => Navigator.of(context).pop(),
            onPreviousEpisode: () => unawaited(_handlePreviousEpisodeTap()),
            onNextEpisode: () => unawaited(_handleNextEpisodeTap()),
            onChooseSource: () => unawaited(_handleChooseSourceTap()),
            onDownload: () => unawaited(_handleDownloadTap()),
          );
        },
        enablePip: true,
        overflowMenuCustomItems: const [],
      ),
    );
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
    _position = Duration.zero;
    _duration = Duration.zero;
    _lastPersistedSecond = -1;
    _navigatingToNext = false;
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
    if (_disposed || !mounted) return;
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
        break;
      case BetterPlayerEventType.pause:
        unawaited(_persistProgress());
        break;
      case BetterPlayerEventType.bufferingStart:
        break;
      case BetterPlayerEventType.bufferingEnd:
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

  Future<void> _showSourceChooser(WatchState state) async {
    final sources = state.info?.sources
            .where((source) => isValidWatchSourceUrl(source.url))
            .toList() ??
        const <WatchSource>[];
    if (sources.isEmpty || !mounted) return;

    final selected = await showModalBottomSheet<WatchSource>(
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
    if (selected == null) return;
    _watchCubit.selectSource(selected);
  }

  Future<void> _handleChooseSourceTap() async {
    await _showSourceChooser(_watchCubit.state);
  }

  Future<void> _handlePreviousEpisodeTap() async {
    final state = _watchCubit.state;
    final index = state.currentIndex;
    if (index == null || state.previousRelease == null) return;
    await _goToEpisode(index - 1);
  }

  Future<void> _handleNextEpisodeTap() async {
    final state = _watchCubit.state;
    final index = state.currentIndex;
    if (index == null || state.nextRelease == null) return;
    await _goToEpisode(index + 1);
  }

  Future<void> _handleDownloadTap() async {
    final state = _watchCubit.state;
    final episodeSession = state.currentRelease?.session ?? widget.episodeSession;
    final item = getIt<DownloadsCubit>().state.latestForEpisode(
      widget.animeSession,
      episodeSession,
    );
    await _handleDownloadIconTap(state, item);
  }

  Future<void> _handleDownloadIconTap(
    WatchState state,
    DownloadItem? downloadItem,
  ) async {
    final item = downloadItem;
    if (item == null || item.status == DownloadStatus.cancelled) {
      await _showDownloadOptions(state);
      return;
    }

    final downloadsCubit = getIt<DownloadsCubit>();
    switch (item.status) {
      case DownloadStatus.queued:
        await downloadsCubit.cancel(item.id);
      case DownloadStatus.downloading:
        await downloadsCubit.pause(item.id);
      case DownloadStatus.paused:
        await downloadsCubit.resume(item.id);
      case DownloadStatus.failed:
        await downloadsCubit.retry(item.id);
      case DownloadStatus.completed:
        final message = await DownloadFileLauncher.openVideo(item.filePath);
        if (!mounted || message == null) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      case DownloadStatus.cancelled:
        break;
    }
  }

  Future<void> _showDownloadOptions(WatchState state) async {
    final info = state.info;
    if (info == null || !mounted) return;
    if (info.downloads.isEmpty) {
      await _watchCubit.loadDownloads();
    }
    if (!mounted) return;
    final latest = _watchCubit.state.info;
    final downloads = latest?.downloads ?? const <WatchDownload>[];
    if (downloads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No download sources found for this episode.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<WatchDownload>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: downloads.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final download = downloads[index];
            return ListTile(
              title: Text(download.label),
              onTap: () => Navigator.of(context).pop(download),
            );
          },
        ),
      ),
    );
    if (selected == null) return;

    await _enqueueDownload(latest!, selected);
  }

  Future<void> _enqueueDownload(WatchInfo info, WatchDownload download) async {
    String downloadUrl;
    try {
      if (download.download.trim().isNotEmpty) {
        downloadUrl = download.download.trim();
      } else {
        downloadUrl = await _watchCubit.resolveDownloadUrl(download);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not resolve download: $error')));
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

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added to downloads queue.')));
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
            return Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      state.error ?? 'Failed to load episode.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: IconButton.filled(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          if (state.info == null) return const SizedBox.shrink();
          if (_playerController == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return BetterPlayer(controller: _playerController!);
        },
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
