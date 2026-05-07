import 'package:equatable/equatable.dart';

final class WatchHistoryItem extends Equatable {
  const WatchHistoryItem({
    required this.animeSession,
    required this.episodeSession,
    required this.animeTitle,
    required this.episodeLabel,
    required this.poster,
    required this.snapshot,
    required this.positionMs,
    required this.durationMs,
    required this.progress,
    required this.updatedAt,
  });

  final String animeSession;
  final String episodeSession;
  final String animeTitle;
  final String episodeLabel;
  final String poster;
  final String snapshot;
  final int positionMs;
  final int durationMs;
  final double progress;
  final DateTime updatedAt;

  bool get isCompleted => progress >= 0.95;
  bool get canResume => progress > 0.02 && !isCompleted;

  WatchHistoryItem copyWith({
    String? animeSession,
    String? episodeSession,
    String? animeTitle,
    String? episodeLabel,
    String? poster,
    String? snapshot,
    int? positionMs,
    int? durationMs,
    double? progress,
    DateTime? updatedAt,
  }) {
    return WatchHistoryItem(
      animeSession: animeSession ?? this.animeSession,
      episodeSession: episodeSession ?? this.episodeSession,
      animeTitle: animeTitle ?? this.animeTitle,
      episodeLabel: episodeLabel ?? this.episodeLabel,
      poster: poster ?? this.poster,
      snapshot: snapshot ?? this.snapshot,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      progress: progress ?? this.progress,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'animeSession': animeSession,
      'episodeSession': episodeSession,
      'animeTitle': animeTitle,
      'episodeLabel': episodeLabel,
      'poster': poster,
      'snapshot': snapshot,
      'positionMs': positionMs,
      'durationMs': durationMs,
      'progress': progress,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory WatchHistoryItem.fromJson(Map<dynamic, dynamic> json) {
    return WatchHistoryItem(
      animeSession: '${json['animeSession'] ?? ''}',
      episodeSession: '${json['episodeSession'] ?? ''}',
      animeTitle: '${json['animeTitle'] ?? ''}',
      episodeLabel: '${json['episodeLabel'] ?? ''}',
      poster: '${json['poster'] ?? ''}',
      snapshot: '${json['snapshot'] ?? ''}',
      positionMs: int.tryParse('${json['positionMs'] ?? 0}') ?? 0,
      durationMs: int.tryParse('${json['durationMs'] ?? 0}') ?? 0,
      progress: double.tryParse('${json['progress'] ?? 0}') ?? 0,
      updatedAt:
          DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    animeSession,
    episodeSession,
    animeTitle,
    episodeLabel,
    poster,
    snapshot,
    positionMs,
    durationMs,
    progress,
    updatedAt,
  ];
}
