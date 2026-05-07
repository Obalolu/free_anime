part of 'search_cubit.dart';

enum SearchStatus { initial, loading, success, failure }

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.items = const [],
    this.recentQueries = const [],
    this.page = 1,
    this.hasMore = true,
    this.loadingMore = false,
    this.error,
  });

  final SearchStatus status;
  final String query;
  final List<SearchItem> items;
  final List<String> recentQueries;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final String? error;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<SearchItem>? items,
    List<String>? recentQueries,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    String? error,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      items: items ?? this.items,
      recentQueries: recentQueries ?? this.recentQueries,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    query,
    items,
    recentQueries,
    page,
    hasMore,
    loadingMore,
    error,
  ];
}
