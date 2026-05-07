part of 'watchlist_cubit.dart';

class WatchlistState extends Equatable {
  const WatchlistState({this.items = const []});

  final List<WatchlistItem> items;

  WatchlistState copyWith({List<WatchlistItem>? items}) =>
      WatchlistState(items: items ?? this.items);

  @override
  List<Object?> get props => [items];
}
