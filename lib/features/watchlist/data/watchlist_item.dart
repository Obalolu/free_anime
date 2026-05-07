import 'package:equatable/equatable.dart';

final class WatchlistItem extends Equatable {
  const WatchlistItem({
    required this.session,
    required this.title,
    required this.poster,
  });

  final String session;
  final String title;
  final String poster;

  Map<String, dynamic> toJson() => {
    'session': session,
    'title': title,
    'poster': poster,
  };

  factory WatchlistItem.fromJson(Map<dynamic, dynamic> json) {
    return WatchlistItem(
      session: '${json['session'] ?? ''}',
      title: '${json['title'] ?? ''}',
      poster: '${json['poster'] ?? ''}',
    );
  }

  @override
  List<Object?> get props => [session, title, poster];
}
