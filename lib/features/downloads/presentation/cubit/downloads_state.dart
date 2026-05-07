part of 'downloads_cubit.dart';

final class DownloadAnimeGroup extends Equatable {
  const DownloadAnimeGroup({
    required this.key,
    required this.title,
    required this.poster,
    required this.items,
  });

  final String key;
  final String title;
  final String poster;
  final List<DownloadItem> items;

  int get completedCount => items.where((item) => item.isCompleted).length;

  int get activeCount => items.where((item) => item.isActive).length;

  int get failedCount =>
      items.where((item) => item.status == DownloadStatus.failed).length;

  int get pausedCount =>
      items.where((item) => item.status == DownloadStatus.paused).length;

  bool get hasActiveDownloads => activeCount > 0;

  List<DownloadItem> get sortedEpisodes {
    final sorted = [...items];
    sorted.sort((left, right) {
      final episodeCompare = _episodeSortValue(
        left,
      ).compareTo(_episodeSortValue(right));
      if (episodeCompare != 0) return episodeCompare;

      return right.createdAt.compareTo(left.createdAt);
    });
    return sorted;
  }

  @override
  List<Object?> get props => [key, title, poster, items];
}

final class DownloadsState extends Equatable {
  const DownloadsState({this.items = const []});

  final List<DownloadItem> items;

  List<DownloadItem> get queue => items.where((item) => item.isActive).toList();
  List<DownloadItem> get history =>
      items.where((item) => !item.isActive).toList();

  int get activeCount => items.where((item) => item.isActive).length;

  int get completedCount => items.where((item) => item.isCompleted).length;

  List<DownloadAnimeGroup> get animeGroups {
    final groups = <String, List<DownloadItem>>{};
    for (final item in items) {
      groups
          .putIfAbsent(item.animeGroupingKey, () => <DownloadItem>[])
          .add(item);
    }

    final result = groups.entries.map((entry) {
      final groupItems = [...entry.value]
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
      final leadItem = groupItems.first;
      final poster = groupItems
          .map((item) => item.animePoster.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      return DownloadAnimeGroup(
        key: entry.key,
        title: leadItem.animeTitle.trim().isEmpty
            ? 'Unknown title'
            : leadItem.animeTitle,
        poster: poster,
        items: groupItems,
      );
    }).toList();

    result.sort((left, right) {
      final leftIsActive = left.hasActiveDownloads ? 1 : 0;
      final rightIsActive = right.hasActiveDownloads ? 1 : 0;
      if (leftIsActive != rightIsActive) {
        return rightIsActive.compareTo(leftIsActive);
      }

      final rightLatest = right.items.first.createdAt;
      final leftLatest = left.items.first.createdAt;
      return rightLatest.compareTo(leftLatest);
    });

    return result;
  }

  DownloadItem? latestForEpisode(String animeSession, String episodeSession) {
    final matches =
        items
            .where(
              (item) =>
                  item.normalizedAnimeSession == animeSession.trim() &&
                  item.normalizedEpisodeSession == episodeSession.trim(),
            )
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

    return matches.isEmpty ? null : matches.first;
  }

  DownloadItem? completedDownloadFor(
    String animeSession,
    String episodeSession,
  ) {
    final matches =
        items
            .where(
              (item) =>
                  item.normalizedAnimeSession == animeSession.trim() &&
                  item.normalizedEpisodeSession == episodeSession.trim() &&
                  item.hasOfflineFile,
            )
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

    return matches.isEmpty ? null : matches.first;
  }

  DownloadsState copyWith({List<DownloadItem>? items}) {
    return DownloadsState(items: items ?? this.items);
  }

  @override
  List<Object?> get props => [items];
}

double _episodeSortValue(DownloadItem item) {
  final source = item.episode.trim().isNotEmpty
      ? item.episode.trim()
      : item.episodeLabel.trim();
  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(source);
  return double.tryParse(match?.group(1) ?? '') ?? double.infinity;
}
