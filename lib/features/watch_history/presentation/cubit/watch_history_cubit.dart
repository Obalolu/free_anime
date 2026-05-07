import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:free_anime/features/watch_history/data/watch_history_item.dart';
import 'package:free_anime/features/watch_history/data/watch_history_repository.dart';

part 'watch_history_state.dart';

class WatchHistoryCubit extends Cubit<WatchHistoryState> {
  WatchHistoryCubit({required WatchHistoryRepository repository})
    : _repository = repository,
      super(const WatchHistoryState());

  final WatchHistoryRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(items: _repository.load()));
  }

  Future<void> saveProgress(WatchHistoryItem item) async {
    await _repository.upsert(item);
    if (isClosed) return;
    emit(state.copyWith(items: _repository.load()));
  }

  Future<void> remove(String episodeSession) async {
    await _repository.remove(episodeSession);
    if (isClosed) return;
    emit(state.copyWith(items: _repository.load()));
  }

  Future<void> clearCompleted() async {
    await _repository.clearCompleted();
    if (isClosed) return;
    emit(state.copyWith(items: _repository.load()));
  }
}
