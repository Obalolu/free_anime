import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:free_anime/core/di/service_locator.dart';
import 'package:free_anime/core/router/route_paths.dart';
import 'package:free_anime/core/theme/app_theme.dart';
import 'package:free_anime/features/anime_details/data/anime_details_models.dart';
import 'package:free_anime/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:free_anime/features/downloads/data/download_file_launcher.dart';
import 'package:free_anime/features/downloads/data/download_item.dart';
import 'package:free_anime/features/downloads/data/download_request.dart';
import 'package:free_anime/features/downloads/presentation/cubit/downloads_cubit.dart';
import 'package:free_anime/features/watch/data/watch_models.dart';
import 'package:free_anime/features/watch/data/watch_repository.dart';
import 'package:free_anime/features/watch/presentation/view/playback_launcher.dart';
import 'package:free_anime/features/watch/presentation/view/watch_page.dart';
import 'package:free_anime/features/watchlist/data/watchlist_item.dart';
import 'package:free_anime/features/watchlist/presentation/cubit/watchlist_cubit.dart';

class AnimeDetailsPage extends StatefulWidget {
  const AnimeDetailsPage({super.key, required this.session});

  final String session;

  @override
  State<AnimeDetailsPage> createState() => _AnimeDetailsPageState();
}

class _AnimeDetailsPageState extends State<AnimeDetailsPage> {
  bool _expandedSynopsis = false;
  int _selectedDetailsTab = 0;

  @override
  void initState() {
    super.initState();
    context.read<AnimeDetailsCubit>().load(widget.session);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<AnimeDetailsCubit, AnimeDetailsState>(
        builder: (context, state) {
          if (state.status == AnimeDetailsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == AnimeDetailsStatus.failure) {
            return _ErrorView(
              message: state.error ?? 'Failed to load anime details',
              onRetry: () =>
                  context.read<AnimeDetailsCubit>().load(widget.session),
            );
          }
          final details = state.details;
          if (details == null) {
            return _ErrorView(
              message: 'No anime details found.',
              onRetry: () =>
                  context.read<AnimeDetailsCubit>().load(widget.session),
            );
          }
          return CustomScrollView(
            slivers: [
              _HeroHeader(details: details),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ActionRow(
                        details: details,
                        session: widget.session,
                        onViewEpisodes: () =>
                            setState(() => _selectedDetailsTab = 0),
                      ),
                      const SizedBox(height: 20),
                      _SectionTitle(title: 'Synopsis'),
                      const SizedBox(height: 8),
                      Text(
                        details.synopsis,
                        maxLines: _expandedSynopsis ? null : 4,
                        overflow: _expandedSynopsis
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(
                          () => _expandedSynopsis = !_expandedSynopsis,
                        ),
                        child: Text(
                          _expandedSynopsis ? 'Show less' : 'Show more',
                        ),
                      ),
                      if (_expandedSynopsis) ...[
                        const SizedBox(height: 16),
                        _MetaWrap(details: details),
                        const SizedBox(height: 16),
                        _InfoTable(details: details),
                        const SizedBox(height: 20),
                        _ChipsSection(title: 'Genres', items: details.genre),
                        _ChipsSection(title: 'Themes', items: details.themes),
                        _ChipsSection(
                          title: 'Demographic',
                          items: details.demographic,
                        ),
                        if (details.externalLinks.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _SectionTitle(title: 'External Links'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: details.externalLinks
                                .map(_buildExternalLinkTile)
                                .toList(),
                          ),
                        ],
                      ],
                      const SizedBox(height: 20),
                      _AnimeDetailsTabs(
                        details: details,
                        releases: state.releases,
                        animeSession: widget.session,
                        selectedIndex: _selectedDetailsTab,
                        onSelected: (index) =>
                            setState(() => _selectedDetailsTab = index),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExternalLinkTile(AnimeExternalLink link) {
    final context = this.context;
    final name = link.name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () async {
          final uri = Uri.tryParse(link.url);
          if (uri == null) return;
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!launched && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open ${name.isEmpty ? 'link' : name}'),
              ),
            );
          }
        },
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          name.isEmpty ? link.url : name,
          style: const TextStyle(
            decoration: TextDecoration.underline,
            decorationColor: AppTheme.primary,
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatefulWidget {
  const _HeroHeader({required this.details});

  final AnimeDetails details;

  @override
  State<_HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<_HeroHeader> {
  YoutubePlayerController? _controller;
  String? _videoId;
  bool _isPlaying = false;
  bool _hasPlaybackError = false;
  bool _isPlayerReady = false;

  AnimeDetails get details => widget.details;

  @override
  void initState() {
    super.initState();
    _videoId = _youtubeVideoId(details.preview);
    if (_videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: _videoId!,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          loop: false,
          enableCaption: true,
          controlsVisibleAtStart: true,
          disableDragSeek: false,
          useHybridComposition: true,
        ),
      )..addListener(_playerListener);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_playerListener);
    _controller?.dispose();
    super.dispose();
  }

  void _playerListener() {
    final controller = _controller;
    if (!mounted || controller == null || !controller.value.hasError) return;
    setState(() {
      _hasPlaybackError = true;
      _isPlaying = false;
    });
  }

  void _playPreview() {
    final videoId = _videoId;
    final controller = _controller;
    if (videoId == null || controller == null) {
      _openPreviewExternally();
      return;
    }

    setState(() {
      _hasPlaybackError = false;
      _isPlaying = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isPlayerReady) {
        controller.load(videoId);
      }
    });
  }

  Future<void> _openPreviewExternally() async {
    final uri = Uri.tryParse(details.preview);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final mediaHeight = MediaQuery.of(context).size.width * 9 / 16;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: mediaHeight,
                width: double.infinity,
                child: _hasPlaybackError
                    ? _PreviewErrorFallback(
                        image: details.image,
                        onOpenExternally: _openPreviewExternally,
                        onRetry: _playPreview,
                      )
                    : _isPlaying && _controller != null
                    ? YoutubePlayerBuilder(
                        player: YoutubePlayer(
                          controller: _controller!,
                          aspectRatio: 16 / 9,
                          showVideoProgressIndicator: true,
                          progressIndicatorColor: AppTheme.primary,
                          progressColors: const ProgressBarColors(
                            playedColor: AppTheme.primary,
                            handleColor: AppTheme.primary,
                          ),
                          onReady: () {
                            _isPlayerReady = true;
                            _controller?.load(_videoId!);
                          },
                        ),
                        builder: (context, player) => player,
                      )
                    : _PreviewPoster(
                        image: details.image,
                        hasPreview: details.preview.isNotEmpty,
                        onPlay: _playPreview,
                      ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton.filledTonal(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 104,
                    height: 148,
                    child: details.image.isEmpty
                        ? Container(color: const Color(0xFF22222D))
                        : CachedNetworkImage(
                            imageUrl: details.image,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          details.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              [
                                    details.type,
                                    details.season,
                                    details.status,
                                    if (details.episodes.isNotEmpty)
                                      '${details.episodes} eps',
                                  ]
                                  .where(
                                    (item) =>
                                        item.trim().isNotEmpty &&
                                        item.trim() != 'null',
                                  )
                                  .map((item) => _HeroBadge(label: item))
                                  .toList(),
                        ),
                        if (details.preview.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _isPlaying
                                ? _openPreviewExternally
                                : _playPreview,
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.play_circle_outline_rounded),
                            label: Text(
                              _isPlaying ? 'Open preview' : 'Play preview',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _youtubeVideoId(String value) {
    final id = YoutubePlayer.convertUrlToId(value.trim());
    if (id != null) return id;

    final match = RegExp(r'[A-Za-z0-9_-]{11}').firstMatch(value);
    return match?.group(0);
  }
}

class _PreviewErrorFallback extends StatelessWidget {
  const _PreviewErrorFallback({
    required this.image,
    required this.onOpenExternally,
    required this.onRetry,
  });

  final String image;
  final VoidCallback onOpenExternally;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        image.isEmpty
            ? Container(color: const Color(0xFF1A1A22))
            : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
        const DecoratedBox(decoration: BoxDecoration(color: Color(0xCC0F0F14))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Preview cannot play inline on this device.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'This trailer may block embedded playback even though it works on YouTube.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    onPressed: onOpenExternally,
                    child: const Text('Open in YouTube'),
                  ),
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewPoster extends StatelessWidget {
  const _PreviewPoster({
    required this.image,
    required this.hasPreview,
    required this.onPlay,
  });

  final String image;
  final bool hasPreview;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: hasPreview ? onPlay : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image.isEmpty
              ? Container(color: const Color(0xFF1A1A22))
              : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x22000000), Color(0xCC0F0F14)],
                stops: [0.2, 1],
              ),
            ),
          ),
          if (hasPreview)
            Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(70),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF22222E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.details,
    required this.session,
    required this.onViewEpisodes,
  });

  final AnimeDetails details;
  final String session;
  final VoidCallback onViewEpisodes;

  @override
  Widget build(BuildContext context) {
    final isInWatchlist = context.select<WatchlistCubit, bool>(
      (cubit) => cubit.state.items.any((e) => e.session == session),
    );
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onViewEpisodes,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('View Episodes'),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () async {
            await context.read<WatchlistCubit>().toggle(
              WatchlistItem(
                session: session,
                title: details.title,
                poster: details.image,
              ),
            );
          },
          icon: Icon(isInWatchlist ? Icons.check_rounded : Icons.add_rounded),
          label: Text(isInWatchlist ? 'In Watchlist' : 'Watchlist'),
        ),
      ],
    );
  }
}

class _MetaWrap extends StatelessWidget {
  const _MetaWrap({required this.details});

  final AnimeDetails details;

  @override
  Widget build(BuildContext context) {
    final items = [
      details.type,
      details.status,
      details.season,
      '${details.episodes} eps',
    ].where((e) => e.trim().isNotEmpty && e.trim() != 'null').toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF21212D),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(e, style: Theme.of(context).textTheme.labelMedium),
            ),
          )
          .toList(),
    );
  }
}

class _InfoTable extends StatelessWidget {
  const _InfoTable({required this.details});

  final AnimeDetails details;

  @override
  Widget build(BuildContext context) {
    final rows =
        <MapEntry<String, String>>[
              MapEntry('Japanese', details.japanese),
              MapEntry('Synonym', details.synonym),
              MapEntry('Aired', details.aired),
              MapEntry('Duration', details.duration),
              MapEntry('Studio', details.studio),
            ]
            .where((e) => e.value.trim().isNotEmpty && e.value.trim() != 'null')
            .toList();

    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      row.key,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(row.value)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ChipsSection extends StatelessWidget {
  const _ChipsSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: title),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Chip(
                    label: Text(item),
                    side: const BorderSide(color: Color(0x55D5015B)),
                    backgroundColor: const Color(0xFF1E1E28),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AnimeDetailsTabs extends StatelessWidget {
  const _AnimeDetailsTabs({
    required this.details,
    required this.releases,
    required this.animeSession,
    required this.selectedIndex,
    required this.onSelected,
  });

  final AnimeDetails details;
  final List<AnimeEpisodeRelease> releases;
  final String animeSession;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailsTabBar(selectedIndex: selectedIndex, onSelected: onSelected),
        const SizedBox(height: 16),
        switch (selectedIndex) {
          0 => _EpisodesTab(
            releases: releases,
            animeSession: animeSession,
            animeTitle: details.title,
            animePoster: details.image,
          ),
          1 => _RelatedTab(details: details),
          _ => _RecommendationsTab(details: details),
        },
      ],
    );
  }
}

class _DetailsTabBar extends StatelessWidget {
  const _DetailsTabBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const tabs = ['Episodes', 'Related', 'Recommendations'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF292932))),
      ),
      child: Row(
        children: [
          for (var index = 0; index < tabs.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tabs[index],
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selectedIndex == index
                              ? Colors.white
                              : Colors.white70,
                          fontWeight: selectedIndex == index
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 2,
                        width: selectedIndex == index ? double.infinity : 0,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EpisodesTab extends StatelessWidget {
  const _EpisodesTab({
    required this.releases,
    required this.animeSession,
    required this.animeTitle,
    required this.animePoster,
  });

  final List<AnimeEpisodeRelease> releases;
  final String animeSession;
  final String animeTitle;
  final String animePoster;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadsCubit, DownloadsState>(
      bloc: getIt<DownloadsCubit>(),
      builder: (context, downloadsState) {
        if (releases.isEmpty) {
          return const _EmptyTab(message: 'No episodes found.');
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: releases.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final release = releases[index];
            return _EpisodeTile(
              release: release,
              animeSession: animeSession,
              animeTitle: animeTitle,
              animePoster: animePoster,
              downloadItem: downloadsState.latestForEpisode(
                animeSession,
                release.session,
              ),
            );
          },
        );
      },
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.release,
    required this.animeSession,
    required this.animeTitle,
    required this.animePoster,
    this.downloadItem,
  });

  final AnimeEpisodeRelease release;
  final String animeSession;
  final String animeTitle;
  final String animePoster;
  final DownloadItem? downloadItem;

  @override
  Widget build(BuildContext context) {
    final episodeLabel = release.episode.trim().isEmpty
        ? '?'
        : release.episode.trim();
    final title = release.title.trim().isEmpty
        ? 'Episode $episodeLabel'
        : release.title.trim();
    final metadata = [
      if (release.duration.trim().isNotEmpty) release.duration.trim(),
      if (release.audio.trim().isNotEmpty) release.audio.trim(),
    ].join(' • ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: release.session.isEmpty
            ? null
            : () => _handleTap(context, episodeLabel, title),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF191922),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF292932)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                child: SizedBox(
                  width: 124,
                  height: 72,
                  child: release.snapshot.isEmpty
                      ? Container(color: const Color(0xFF22222D))
                      : CachedNetworkImage(
                          imageUrl: release.snapshot,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Episode $episodeLabel',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          metadata,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                      if (downloadItem != null) ...[
                        const SizedBox(height: 8),
                        _EpisodeDownloadStateBadge(
                          status: downloadItem!.status,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _EpisodeDownloadActionButton(
                  downloadItem: downloadItem,
                  onPressed: () => _handleDownloadAction(
                    context,
                    episodeLabel: episodeLabel,
                    title: title,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    String episodeLabel,
    String title,
  ) async {
    await PlaybackLauncher.chooseSourceAndPlay(
      context: context,
      animeSession: animeSession,
      episodeSession: release.session,
      extra: WatchPageExtra(
        episode: episodeLabel,
        title: title,
        snapshot: release.snapshot,
        duration: release.duration,
        poster: animePoster.isEmpty ? release.snapshot : animePoster,
      ),
    );
  }

  Future<void> _handleDownloadAction(
    BuildContext context, {
    required String episodeLabel,
    required String title,
  }) async {
    final item = downloadItem;
    if (item == null || item.status == DownloadStatus.cancelled) {
      await _chooseDownloadSourceAndEnqueue(
        context,
        episodeLabel: episodeLabel,
        title: title,
      );
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
        if (!context.mounted || message == null) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      case DownloadStatus.cancelled:
        break;
    }
  }

  Future<void> _chooseDownloadSourceAndEnqueue(
    BuildContext context, {
    required String episodeLabel,
    required String title,
  }) async {
    WatchInfo info;
    try {
      info = await getIt<WatchRepository>().fetchWatchInfo(
        animeSession: animeSession,
        episodeSession: release.session,
        includeDownloads: true,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load downloads: $error')));
      return;
    }

    if (!context.mounted) return;
    final downloads = info.downloads;
    if (downloads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No download source available yet.')),
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
              subtitle: Text('Episode $episodeLabel'),
              onTap: () => Navigator.of(context).pop(download),
            );
          },
        ),
      ),
    );
    if (selected == null || !context.mounted) return;

    await _enqueueDownload(
      context,
      info: info,
      download: selected,
      episodeLabel: episodeLabel,
      title: title,
    );
  }

  Future<void> _enqueueDownload(
    BuildContext context, {
    required WatchInfo info,
    required WatchDownload download,
    required String episodeLabel,
    required String title,
  }) async {
    String downloadUrl;
    try {
      downloadUrl = download.download.trim().isNotEmpty
          ? download.download.trim()
          : await getIt<WatchRepository>().resolveDownloadUrl(download.pahe);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not resolve download: $error')));
      return;
    }

    final request = const DownloadUrlResolver().resolve(
      url: downloadUrl,
      downloadPage: download.downloadPage,
    );
    getIt<DownloadsCubit>().enqueue(
      DownloadItem(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        animeSession: animeSession,
        episodeSession: release.session,
        animeTitle: info.animeTitle.isEmpty ? animeTitle : info.animeTitle,
        animePoster: animePoster,
        episode: release.episode,
        episodeLabel: 'Episode $episodeLabel',
        episodeSnapshot: release.snapshot,
        resolution: download.resolution,
        fansub: download.fansub,
        isDub: download.isDub,
        url: request.primaryUrl,
        candidateUrls: request.candidateUrls,
        downloadPage: download.downloadPage,
        referer: request.referer,
        origin: request.origin,
        filename: _filenameFor(
          animeTitle: animeTitle.isEmpty ? title : animeTitle,
          episodeLabel: episodeLabel,
          resolution: download.resolution,
          url: downloadUrl,
        ),
        createdAt: DateTime.now(),
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added to downloads queue.')));
  }

  String _filenameFor({
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

    final safeTitle = animeTitle
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final suffix = resolution.isEmpty ? '' : '_${resolution}p';
    return '${safeTitle}_Episode_$episodeLabel$suffix.mp4';
  }
}

class _EpisodeDownloadActionButton extends StatelessWidget {
  const _EpisodeDownloadActionButton({
    required this.downloadItem,
    required this.onPressed,
  });

  final DownloadItem? downloadItem;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final item = downloadItem;
    final status = item?.status;
    IconData icon;
    Color color;
    Widget? overlay;
    switch (status) {
      case DownloadStatus.queued:
        icon = Icons.schedule_rounded;
        color = AppTheme.primarySoft;
      case DownloadStatus.downloading:
        icon = Icons.pause_rounded;
        color = AppTheme.statusActive;
        overlay = SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            value: item?.progress ?? 0,
            color: AppTheme.statusActive,
          ),
        );
      case DownloadStatus.paused:
        icon = Icons.play_arrow_rounded;
        color = AppTheme.statusPaused;
      case DownloadStatus.failed:
        icon = Icons.refresh_rounded;
        color = AppTheme.statusFailed;
      case DownloadStatus.completed:
        icon = Icons.offline_pin_rounded;
        color = AppTheme.statusComplete;
      case DownloadStatus.cancelled:
      case null:
        icon = Icons.download_rounded;
        color = AppTheme.primary;
    }

    return IconButton(
      tooltip: 'Download actions',
      onPressed: onPressed,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          if (overlay != null) overlay,
          Icon(icon, color: color),
        ],
      ),
    );
  }
}

class _EpisodeDownloadStateBadge extends StatelessWidget {
  const _EpisodeDownloadStateBadge({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      DownloadStatus.completed => AppTheme.statusComplete,
      DownloadStatus.downloading => AppTheme.statusActive,
      DownloadStatus.queued => AppTheme.primarySoft,
      DownloadStatus.paused => AppTheme.statusPaused,
      DownloadStatus.failed => AppTheme.statusFailed,
      DownloadStatus.cancelled => AppTheme.statusMuted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        status == DownloadStatus.completed ? 'Offline ready' : status.name,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _RelatedTab extends StatelessWidget {
  const _RelatedTab({required this.details});

  final AnimeDetails details;

  @override
  Widget build(BuildContext context) {
    final groups = details.relations.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();
    if (groups.isEmpty) {
      return const _EmptyTab(message: 'No related shows found.');
    }

    return Column(
      children: groups
          .map((entry) => _RelationGroup(title: entry.key, items: entry.value))
          .toList(),
    );
  }
}

class _RecommendationsTab extends StatelessWidget {
  const _RecommendationsTab({required this.details});

  final AnimeDetails details;

  @override
  Widget build(BuildContext context) {
    if (details.recommendations.isEmpty) {
      return const _EmptyTab(message: 'No recommendations found.');
    }

    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: details.recommendations.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = details.recommendations[index];
          return _PosterCard(
            title: item.title,
            image: item.image,
            subtitle: '${item.type} • ${item.episodes} eps',
            onTap: item.session.isEmpty
                ? null
                : () => context.push(
                    RoutePaths.animeDetailsBySession(item.session),
                  ),
          );
        },
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF191922),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF292932)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _RelationGroup extends StatelessWidget {
  const _RelationGroup({required this.title, required this.items});

  final String title;
  final List<AnimeRelatedItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: title),
          const SizedBox(height: 10),
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _PosterCard(
                  title: item.title,
                  image: item.image,
                  subtitle: '${item.type} • ${item.episodes} eps',
                  onTap: item.session.isEmpty
                      ? null
                      : () => context.push(
                          RoutePaths.animeDetailsBySession(item.session),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.title,
    required this.image,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String image;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: image.isEmpty
                    ? Container(color: const Color(0xFF22222D))
                    : CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
