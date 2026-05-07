import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:free_anime/core/router/route_paths.dart';
import 'package:free_anime/core/widgets/anime_ui.dart';
import 'package:free_anime/features/watch/presentation/view/playback_launcher.dart';
import 'package:free_anime/features/watch/presentation/view/watch_page.dart';
import 'package:free_anime/features/watch_history/presentation/cubit/watch_history_cubit.dart';
import 'package:free_anime/features/watchlist/presentation/cubit/watchlist_cubit.dart';

class WatchlistPage extends StatefulWidget {
  const WatchlistPage({super.key});

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  @override
  void initState() {
    super.initState();
    context.read<WatchlistCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Watchlist')),
      body: BlocBuilder<WatchlistCubit, WatchlistState>(
        builder: (context, state) {
          final history = context
              .watch<WatchHistoryCubit>()
              .state
              .continueWatching;
          return CustomScrollView(
            slivers: [
              if (history.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Resume',
                          subtitle:
                              'Your recent episodes stay close to your library.',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 240,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: history.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final item = history[index];
                              return ContinueWatchingCard(
                                title: item.animeTitle,
                                episodeLabel: item.episodeLabel,
                                imageUrl: item.snapshot.isNotEmpty
                                    ? item.snapshot
                                    : item.poster,
                                progress: item.progress,
                                progressText:
                                    '${_formatDuration(item.positionMs)} / ${_formatDuration(item.durationMs)}',
                                onTap: () => PlaybackLauncher.launchFullscreen(
                                  context: context,
                                  animeSession: item.animeSession,
                                  episodeSession: item.episodeSession,
                                  extra: WatchPageExtra(
                                    episode: item.episodeLabel.replaceFirst(
                                      'Episode ',
                                      '',
                                    ),
                                    title: item.animeTitle,
                                    snapshot: item.snapshot,
                                    duration: _formatDuration(item.durationMs),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Your watchlist',
                    subtitle:
                        '${state.items.length} saved title${state.items.length == 1 ? '' : 's'}',
                  ),
                ),
              ),
              if (state.items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: EmptyStateCard(
                      title: 'Nothing saved yet',
                      message:
                          'Add shows from the details page to build a personal library.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.64,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = state.items[index];
                      return PosterGridCard(
                        title: item.title,
                        imageUrl: item.poster,
                        subtitle: 'Saved for later',
                        onTap: item.session.isEmpty
                            ? null
                            : () => context.push(
                                RoutePaths.animeDetailsBySession(item.session),
                              ),
                        trailing: IconButton.filledTonal(
                          onPressed: () =>
                              context.read<WatchlistCubit>().toggle(item),
                          icon: const Icon(
                            Icons.bookmark_remove_rounded,
                            size: 18,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xAA171720),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      );
                    }, childCount: state.items.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    if (milliseconds <= 0) return '--:--';
    final totalSeconds = milliseconds ~/ 1000;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
