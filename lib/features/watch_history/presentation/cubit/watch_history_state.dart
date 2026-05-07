part of 'watch_history_cubit.dart';

class WatchHistoryState extends Equatable {
  const WatchHistoryState({this.items = const []});

  final List<WatchHistoryItem> items;

  List<WatchHistoryItem> get continueWatching =>
      items.where((item) => item.canResume).toList();

  WatchHistoryState copyWith({List<WatchHistoryItem>? items}) {
    return WatchHistoryState(items: items ?? this.items);
  }

  @override
  List<Object?> get props => [items];
}
