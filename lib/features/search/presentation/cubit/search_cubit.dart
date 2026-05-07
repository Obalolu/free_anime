import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/search_item.dart';
import '../../data/search_repository.dart';

part 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit({required SearchRepository repository})
    : _repository = repository,
      super(const SearchState());

  final SearchRepository _repository;
  Timer? _debounce;
  int _requestId = 0;

  void loadRecentQueries() {
    emit(state.copyWith(recentQueries: _repository.loadRecentQueries()));
  }

  void onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => search(query));
  }

  Future<void> search(String query) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) {
      emit(
        state.copyWith(
          status: SearchStatus.initial,
          query: '',
          items: const [],
          page: 1,
          hasMore: true,
          loadingMore: false,
          error: null,
          recentQueries: _repository.loadRecentQueries(),
        ),
      );
      return;
    }

    final requestId = ++_requestId;
    emit(
      state.copyWith(
        status: SearchStatus.loading,
        query: cleaned,
        error: null,
        page: 1,
        hasMore: true,
        loadingMore: false,
      ),
    );
    try {
      final items = await _repository.search(query: cleaned);
      if (isClosed || requestId != _requestId) return;
      emit(
        state.copyWith(
          status: SearchStatus.success,
          items: items,
          page: 1,
          hasMore: items.isNotEmpty,
          recentQueries: _repository.loadRecentQueries(),
        ),
      );
    } catch (error) {
      if (isClosed || requestId != _requestId) return;
      emit(
        state.copyWith(status: SearchStatus.failure, error: error.toString()),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore ||
        state.status == SearchStatus.loading ||
        state.query.isEmpty ||
        !state.hasMore) {
      return;
    }

    emit(state.copyWith(loadingMore: true, error: null));
    final nextPage = state.page + 1;
    try {
      final items = await _repository.search(
        query: state.query,
        page: nextPage,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: SearchStatus.success,
          items: [...state.items, ...items],
          page: nextPage,
          hasMore: items.isNotEmpty,
          loadingMore: false,
          recentQueries: _repository.loadRecentQueries(),
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(loadingMore: false, error: error.toString()));
    }
  }

  Future<void> clearHistory() async {
    await _repository.clearRecentQueries();
    if (isClosed) return;
    emit(state.copyWith(recentQueries: const []));
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
