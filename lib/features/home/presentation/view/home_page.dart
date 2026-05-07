import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:free_anime/core/widgets/anime_ui.dart';
import 'package:free_anime/core/router/route_paths.dart';
import 'package:free_anime/features/home/presentation/cubit/home_cubit.dart';
import 'package:free_anime/features/watch/presentation/view/playback_launcher.dart';
import 'package:free_anime/features/watch/presentation/view/watch_page.dart';
import 'package:free_anime/features/watch_history/presentation/cubit/watch_history_cubit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scrollController = ScrollController();
  final _heroController = PageController(viewportFraction: 0.88);

  @override
  void initState() {
    super.initState();
    context.read<HomeCubit>().load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _heroController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 500) {
      context.read<HomeCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse')),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state.status == HomeStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == HomeStatus.failure) {
            return Center(
              child: Text(state.error ?? 'Failed to load airing list'),
            );
          }
          final history = context
              .watch<WatchHistoryCubit>()
              .state
              .continueWatching;
          final items = state.items;
          final heroItems = items.take(5).toList();
          final gridItems = items.skip(heroItems.length).toList();

          return RefreshIndicator(
            onRefresh: () => context.read<HomeCubit>().load(),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (history.isNotEmpty) ...[
                          const SectionHeader(
                            title: 'Continue watching',
                            subtitle: 'Pick up right where you stopped.',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 250,
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
                                      duration: _formatDuration(
                                        item.durationMs,
                                      ),
                                    ),
                                  ),
                                  onDismiss: () => context
                                      .read<WatchHistoryCubit>()
                                      .remove(item.episodeSession),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        const SectionHeader(
                          title: 'Airing now',
                          subtitle:
                              'Fresh episodes with a faster visual browse.',
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 340,
                    child: PageView.builder(
                      controller: _heroController,
                      itemCount: heroItems.length,
                      itemBuilder: (context, index) {
                        final item = heroItems[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            left: index == 0 ? 16 : 6,
                            right: index == heroItems.length - 1 ? 16 : 6,
                          ),
                          child: AiringHeroCard(
                            title: item.title,
                            episode: item.episode,
                            imageUrl: item.image,
                            onTap: item.session.isEmpty
                                ? null
                                : () => context.push(
                                    RoutePaths.animeDetailsBySession(
                                      item.session,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  sliver: const SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Latest releases',
                      subtitle: 'Grid browsing replaces the old tile list.',
                    ),
                  ),
                ),
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
                      final item = gridItems[index];
                      return PosterGridCard(
                        title: item.title,
                        imageUrl: item.image,
                        subtitle: 'Episode ${item.episode}',
                        onTap: item.session.isEmpty
                            ? null
                            : () => context.push(
                                RoutePaths.animeDetailsBySession(item.session),
                              ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xAA0F0F14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'EP ${item.episode}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      );
                    }, childCount: gridItems.length),
                  ),
                ),
                if (state.loadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
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
