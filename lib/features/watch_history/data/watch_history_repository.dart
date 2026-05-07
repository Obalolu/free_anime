import 'package:hive/hive.dart';

import 'watch_history_item.dart';

abstract interface class WatchHistoryRepository {
  List<WatchHistoryItem> load();
  Future<void> upsert(WatchHistoryItem item);
  Future<void> remove(String episodeSession);
  Future<void> clearCompleted();
}

final class WatchHistoryRepositoryImpl implements WatchHistoryRepository {
  WatchHistoryRepositoryImpl({required Box box}) : _box = box;

  final Box _box;

  @override
  List<WatchHistoryItem> load() {
    final items =
        _box.values
            .whereType<Map>()
            .map(WatchHistoryItem.fromJson)
            .where((item) => item.episodeSession.isNotEmpty)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  @override
  Future<void> upsert(WatchHistoryItem item) async {
    await _box.put(item.episodeSession, item.toJson());
  }

  @override
  Future<void> remove(String episodeSession) => _box.delete(episodeSession);

  @override
  Future<void> clearCompleted() async {
    final completedKeys = _box
        .toMap()
        .entries
        .whereType<MapEntry<dynamic, dynamic>>()
        .where((entry) {
          final value = entry.value;
          if (value is! Map) return false;
          final item = WatchHistoryItem.fromJson(value);
          return item.isCompleted;
        })
        .map((entry) => entry.key)
        .toList();
    if (completedKeys.isEmpty) return;
    await _box.deleteAll(completedKeys);
  }
}
