import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:free_anime/core/di/service_locator.dart';
import 'package:free_anime/core/router/app_router.dart';
import 'package:free_anime/core/theme/app_theme.dart';
import 'package:free_anime/features/home/presentation/cubit/home_cubit.dart';
import 'package:free_anime/features/search/presentation/cubit/search_cubit.dart';
import 'package:free_anime/features/settings/presentation/cubit/theme_mode_cubit.dart';
import 'package:free_anime/features/watchlist/presentation/cubit/watchlist_cubit.dart';
import 'package:free_anime/features/watch_history/presentation/cubit/watch_history_cubit.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final _router = AppRouter.build();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeModeCubit>.value(value: getIt<ThemeModeCubit>()),
        BlocProvider<WatchHistoryCubit>.value(
          value: getIt<WatchHistoryCubit>(),
        ),
        BlocProvider<HomeCubit>(create: (_) => getIt<HomeCubit>()),
        BlocProvider<SearchCubit>(create: (_) => getIt<SearchCubit>()),
        BlocProvider<WatchlistCubit>(
          create: (_) => getIt<WatchlistCubit>()..load(),
        ),
      ],
      child: BlocBuilder<ThemeModeCubit, ThemeMode>(
        builder: (context, mode) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Free Anime',
            theme: AppTheme.dark(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
