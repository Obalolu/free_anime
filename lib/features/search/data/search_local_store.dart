import 'package:hive/hive.dart';

import 'search_item.dart';

final class SearchLocalStore {
  SearchLocalStore({required Box historyBox, required Box cacheBox})
    : _historyBox = historyBox,
      _cacheBox = cacheBox;

  final Box _historyBox;
  final Box _cacheBox;

  static const _historyKey = 'recent_queries';
  static const _ttl = Duration(hours: 6);

  List<String> loadRecentQueries() {
    final values = _historyBox.get(_historyKey);
    if (values is! List) return <String>[];
    return values
        .map((value) => '$value')
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Future<void> saveRecentQuery(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    final current = loadRecentQueries()
      ..removeWhere((value) => value.toLowerCase() == normalized.toLowerCase())
      ..insert(0, normalized);
    await _historyBox.put(_historyKey, current.take(10).toList());
  }

  Future<void> clearRecentQueries() => _historyBox.delete(_historyKey);

  List<SearchItem>? loadCachedResults(String query, int page) {
    final raw = _cacheBox.get(_cacheKey(query, page));
    if (raw is! Map) return null;
    final fetchedAt = DateTime.tryParse('${raw['fetchedAt'] ?? ''}');
    if (fetchedAt == null || DateTime.now().difference(fetchedAt) > _ttl) {
      _cacheBox.delete(_cacheKey(query, page));
      return null;
    }

    final items = raw['items'];
    if (items is! List) return null;
    final parsed = items
        .whereType<Map>()
        .map((item) => SearchItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final hasSearchMetadata = parsed.any(
      (item) =>
          item.status.trim().isNotEmpty ||
          item.type.trim().isNotEmpty ||
          item.episodes.trim().isNotEmpty ||
          item.year.trim().isNotEmpty ||
          item.season.trim().isNotEmpty ||
          item.score.trim().isNotEmpty,
    );
    if (!hasSearchMetadata) {
      _cacheBox.delete(_cacheKey(query, page));
      return null;
    }
    return parsed;
  }

  Future<void> saveCachedResults(
    String query,
    int page,
    List<SearchItem> items,
  ) async {
    await _cacheBox.put(_cacheKey(query, page), {
      'fetchedAt': DateTime.now().toIso8601String(),
      'items': items
          .map(
            (item) => {
              'title': item.title,
              'poster': item.poster,
              'session': item.session,
              'status': item.status,
              'type': item.type,
              'episodes': item.episodes,
              'year': item.year,
              'season': item.season,
              'score': item.score,
            },
          )
          .toList(),
    });
  }

  String _cacheKey(String query, int page) =>
      '${query.trim().toLowerCase()}::$page';
}
