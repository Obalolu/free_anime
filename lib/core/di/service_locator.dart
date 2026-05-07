import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'package:free_anime/core/config/env_config.dart';
import 'package:free_anime/core/network/interceptors/network_retry_interceptor.dart';
import 'package:free_anime/features/downloads/data/downloads_repository.dart';
import 'package:free_anime/features/downloads/presentation/cubit/downloads_cubit.dart';
import 'package:free_anime/features/home/data/airing_repository.dart';
import 'package:free_anime/features/home/presentation/cubit/home_cubit.dart';
import 'package:free_anime/features/anime_details/data/anime_details_repository.dart';
import 'package:free_anime/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:free_anime/features/search/data/search_repository.dart';
import 'package:free_anime/features/search/presentation/cubit/search_cubit.dart';
import 'package:free_anime/features/settings/presentation/cubit/theme_mode_cubit.dart';
import 'package:free_anime/features/watchlist/data/watchlist_repository.dart';
import 'package:free_anime/features/watchlist/presentation/cubit/watchlist_cubit.dart';
import 'package:free_anime/features/watch/data/watch_repository.dart';
import 'package:free_anime/features/watch/presentation/cubit/watch_cubit.dart';
import 'package:free_anime/features/watch_history/data/watch_history_repository.dart';
import 'package:free_anime/features/watch_history/presentation/cubit/watch_history_cubit.dart';
import 'package:free_anime/features/search/data/search_local_store.dart';
import 'package:hive_flutter/hive_flutter.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  if (getIt.isRegistered<Dio>()) return;

  final dio = Dio(
    BaseOptions(
      baseUrl: EnvConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: const {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(NetworkRetryInterceptor(dio));
  dio.interceptors.add(
    PrettyDioLogger(
      requestHeader: true,
      requestBody: false,
      responseHeader: false,
      responseBody: false,
      compact: true,
      enabled: true,
    ),
  );

  final settingsBox = await Hive.openBox('settings');
  final watchlistBox = await Hive.openBox('watchlist');
  final downloadsBox = await Hive.openBox('downloads');
  final watchHistoryBox = await Hive.openBox('watch_history');
  final searchHistoryBox = await Hive.openBox('search_history');
  final searchCacheBox = await Hive.openBox('search_cache');

  getIt
    ..registerSingleton<Dio>(dio)
    ..registerSingleton<Box>(settingsBox, instanceName: 'settings_box')
    ..registerSingleton<Box>(watchlistBox, instanceName: 'watchlist_box')
    ..registerSingleton<Box>(downloadsBox, instanceName: 'downloads_box')
    ..registerSingleton<Box>(watchHistoryBox, instanceName: 'watch_history_box')
    ..registerSingleton<Box>(
      searchHistoryBox,
      instanceName: 'search_history_box',
    )
    ..registerSingleton<Box>(searchCacheBox, instanceName: 'search_cache_box')
    ..registerLazySingleton<SearchLocalStore>(
      () => SearchLocalStore(
        historyBox: getIt<Box>(instanceName: 'search_history_box'),
        cacheBox: getIt<Box>(instanceName: 'search_cache_box'),
      ),
    )
    ..registerLazySingleton<AiringRepository>(
      () => AiringRepositoryImpl(dio: getIt()),
    )
    ..registerLazySingleton<AnimeDetailsRepository>(
      () => AnimeDetailsRepositoryImpl(dio: getIt()),
    )
    ..registerLazySingleton<DownloadsRepository>(
      () => DownloadsRepository(
        box: getIt<Box>(instanceName: 'downloads_box'),
        dio: getIt(),
      ),
    )
    ..registerLazySingleton<WatchRepository>(
      () => WatchRepositoryImpl(dio: getIt()),
    )
    ..registerLazySingleton<SearchRepository>(
      () => SearchRepositoryImpl(dio: getIt(), localStore: getIt()),
    )
    ..registerLazySingleton<WatchlistRepository>(
      () => WatchlistRepositoryImpl(
        box: getIt<Box>(instanceName: 'watchlist_box'),
      ),
    )
    ..registerLazySingleton<WatchHistoryRepository>(
      () => WatchHistoryRepositoryImpl(
        box: getIt<Box>(instanceName: 'watch_history_box'),
      ),
    )
    ..registerFactory<HomeCubit>(() => HomeCubit(repository: getIt()))
    ..registerFactory<AnimeDetailsCubit>(
      () => AnimeDetailsCubit(repository: getIt()),
    )
    ..registerFactory<SearchCubit>(() => SearchCubit(repository: getIt()))
    ..registerFactory<WatchCubit>(
      () => WatchCubit(repository: getIt(), animeDetailsRepository: getIt()),
    )
    ..registerFactory<WatchlistCubit>(() => WatchlistCubit(repository: getIt()))
    ..registerSingleton<WatchHistoryCubit>(
      WatchHistoryCubit(repository: getIt()),
    )
    ..registerSingleton<DownloadsCubit>(DownloadsCubit(repository: getIt()))
    ..registerSingleton<ThemeModeCubit>(
      ThemeModeCubit(box: getIt<Box>(instanceName: 'settings_box')),
    );

  await getIt<DownloadsCubit>().load();
  await getIt<WatchHistoryCubit>().load();
  await getIt<ThemeModeCubit>().load();
}
