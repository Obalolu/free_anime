import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:free_anime/core/di/service_locator.dart';
import 'package:free_anime/core/router/route_paths.dart';
import 'package:free_anime/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:free_anime/features/anime_details/presentation/view/anime_details_page.dart';
import 'package:free_anime/core/theme/app_icons.dart';
import 'package:free_anime/features/downloads/presentation/view/downloads_page.dart';
import 'package:free_anime/features/home/presentation/view/home_page.dart';
import 'package:free_anime/features/search/presentation/view/search_page.dart';
import 'package:free_anime/features/settings/presentation/view/settings_page.dart';
import 'package:free_anime/features/watchlist/presentation/view/watchlist_page.dart';

final class AppRouter {
  AppRouter._();

  static GoRouter build() {
    return GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              _AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.home,
                  builder: (context, state) => const HomePage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.search,
                  builder: (context, state) => const SearchPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.downloads,
                  builder: (context, state) => const DownloadsPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.watchlist,
                  builder: (context, state) => const WatchlistPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.settings,
                  builder: (context, state) => const SettingsPage(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: RoutePaths.animeDetails,
          builder: (context, state) {
            final session = state.pathParameters['session'] ?? '';
            return BlocProvider<AnimeDetailsCubit>(
              create: (_) => getIt<AnimeDetailsCubit>(),
              child: AnimeDetailsPage(session: session),
            );
          },
        ),
      ],
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        destinations: const [
          NavigationDestination(icon: Icon(AppIcons.home), label: 'Home'),
          NavigationDestination(icon: Icon(AppIcons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(AppIcons.downloads),
            label: 'Downloads',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.watchlist),
            label: 'Watchlist',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
