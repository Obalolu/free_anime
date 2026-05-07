import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/airing_item.dart';
import '../../data/airing_repository.dart';

part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required AiringRepository repository})
    : _repository = repository,
      super(const HomeState());

  final AiringRepository _repository;

  Future<void> load() async {
    emit(
      state.copyWith(
        status: HomeStatus.loading,
        error: null,
        page: 1,
        hasMore: true,
        loadingMore: false,
      ),
    );
    try {
      final items = await _repository.fetchAiring(page: 1);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: HomeStatus.success,
          items: items,
          page: 1,
          hasMore: items.isNotEmpty,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(status: HomeStatus.failure, error: error.toString()));
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore ||
        !state.hasMore ||
        state.status == HomeStatus.loading) {
      return;
    }

    emit(state.copyWith(loadingMore: true, error: null));
    final nextPage = state.page + 1;
    try {
      final items = await _repository.fetchAiring(page: nextPage);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: HomeStatus.success,
          items: [...state.items, ...items],
          page: nextPage,
          hasMore: items.isNotEmpty,
          loadingMore: false,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(loadingMore: false, error: error.toString()));
    }
  }
}
