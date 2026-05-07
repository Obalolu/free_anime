final class RoutePaths {
  RoutePaths._();

  static const home = '/home';
  static const search = '/search';
  static const downloads = '/downloads';
  static const watchlist = '/watchlist';
  static const settings = '/settings';
  static const animeDetails = '/anime/:session';

  static String animeDetailsBySession(String session) => '/anime/$session';
}
