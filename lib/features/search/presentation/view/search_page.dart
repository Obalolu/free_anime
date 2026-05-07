import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:free_anime/core/widgets/anime_ui.dart';
import 'package:free_anime/core/router/route_paths.dart';
import 'package:free_anime/features/search/presentation/cubit/search_cubit.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<SearchCubit>().loadRecentQueries();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 400) {
      context.read<SearchCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _controller,
                        onChanged: context.read<SearchCubit>().onQueryChanged,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'Search anime, studios, or seasons...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (state.recentQueries.isNotEmpty &&
                          state.query.isEmpty) ...[
                        SectionHeader(
                          title: 'Recent searches',
                          actionLabel: 'Clear',
                          onAction: () =>
                              context.read<SearchCubit>().clearHistory(),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: state.recentQueries
                              .map(
                                (query) => ActionChip(
                                  label: Text(query),
                                  onPressed: () {
                                    _controller.text = query;
                                    context.read<SearchCubit>().search(query);
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (state.status == SearchStatus.loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.status == SearchStatus.failure)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: EmptyStateCard(
                      title: 'Search failed',
                      message: state.error ?? 'Try again in a moment.',
                    ),
                  ),
                )
              else if (state.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: EmptyStateCard(
                      title: state.query.isEmpty
                          ? 'Find your next anime'
                          : 'No results found',
                      message: state.query.isEmpty
                          ? 'Search by title, studio, or season to start exploring.'
                          : 'Try a shorter title, another fansub spelling, or a broader keyword.',
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Results',
                      subtitle: 'Showing matches for "${state.query}"',
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
                          childAspectRatio: 0.62,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = state.items[index];
                      return PosterGridCard(
                        title: item.title,
                        imageUrl: item.poster,
                        subtitle: item.metadataLine.isEmpty
                            ? 'Anime'
                            : item.metadataLine,
                        onTap: item.session.isEmpty
                            ? null
                            : () => context.push(
                                RoutePaths.animeDetailsBySession(item.session),
                              ),
                      );
                    }, childCount: state.items.length),
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
            ],
          );
        },
      ),
    );
  }
}
