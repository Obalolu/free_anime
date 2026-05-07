import 'package:hive/hive.dart';

import 'watchlist_item.dart';

abstract interface class WatchlistRepository {
  List<WatchlistItem> load();
  Future<void> upsert(WatchlistItem item);
  Future<void> remove(String session);
}

final class WatchlistRepositoryImpl implements WatchlistRepository {
  WatchlistRepositoryImpl({required Box box}) : _box = box;

  final Box _box;

  @override
  List<WatchlistItem> load() {
    return _box.values
        .whereType<Map>()
        .map((value) => WatchlistItem.fromJson(value))
        .where((item) => item.session.isNotEmpty)
        .toList();
  }

  @override
  Future<void> upsert(WatchlistItem item) =>
      _box.put(item.session, item.toJson());

  @override
  Future<void> remove(String session) => _box.delete(session);
}
