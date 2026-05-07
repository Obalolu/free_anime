part of 'home_cubit.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
    this.loadingMore = false,
    this.error,
  });

  final HomeStatus status;
  final List<AiringItem> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final String? error;

  HomeState copyWith({
    HomeStatus? status,
    List<AiringItem>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    String? error,
  }) {
    return HomeState(
      status: status ?? this.status,
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, items, page, hasMore, loadingMore, error];
}
