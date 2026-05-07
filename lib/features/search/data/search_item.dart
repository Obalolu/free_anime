final class SearchItem {
  const SearchItem({
    required this.title,
    required this.poster,
    required this.session,
    required this.status,
    required this.type,
    required this.episodes,
    required this.year,
    required this.season,
    required this.score,
  });

  final String title;
  final String poster;
  final String session;
  final String status;
  final String type;
  final String episodes;
  final String year;
  final String season;
  final String score;

  String get metadataLine {
    final parts = <String>[
      if (type.trim().isNotEmpty) type.trim(),
      if (status.trim().isNotEmpty) status.trim(),
      if (episodes.trim().isNotEmpty) '${episodes.trim()} eps',
      if (season.trim().isNotEmpty && year.trim().isNotEmpty)
        '${season.trim()} ${year.trim()}'
      else if (year.trim().isNotEmpty)
        year.trim()
      else if (season.trim().isNotEmpty)
        season.trim(),
      if (score.trim().isNotEmpty) '★ ${score.trim()}',
    ];
    return parts.join(' • ');
  }

  factory SearchItem.fromJson(Map<String, dynamic> json) {
    return SearchItem(
      title: (json['title'] ?? '') as String,
      poster: (json['poster'] ?? '') as String,
      session: (json['session'] ?? '') as String,
      status: '${json['status'] ?? ''}',
      type: '${json['type'] ?? json['category'] ?? json['format'] ?? ''}',
      episodes:
          '${json['episodes'] ?? json['episode_count'] ?? json['ep_count'] ?? ''}',
      year: '${json['year'] ?? ''}',
      season: '${json['season'] ?? ''}',
      score: '${json['score'] ?? ''}',
    );
  }
}
