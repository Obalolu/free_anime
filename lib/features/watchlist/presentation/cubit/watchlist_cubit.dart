import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/watchlist_item.dart';
import '../../data/watchlist_repository.dart';

part 'watchlist_state.dart';

class WatchlistCubit extends Cubit<WatchlistState> {
  WatchlistCubit({required WatchlistRepository repository})
    : _repository = repository,
      super(const WatchlistState());

  final WatchlistRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(items: _repository.load()));
  }

  Future<void> toggle(WatchlistItem item) async {
    final exists = state.items.any((e) => e.session == item.session);
    if (exists) {
      await _repository.remove(item.session);
    } else {
      await _repository.upsert(item);
    }
    if (isClosed) return;
    emit(state.copyWith(items: _repository.load()));
  }
}
