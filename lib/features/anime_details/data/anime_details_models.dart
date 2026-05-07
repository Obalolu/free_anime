final class AnimeExternalLink {
  const AnimeExternalLink({required this.name, required this.url});

  final String name;
  final String url;

  factory AnimeExternalLink.fromJson(Map<String, dynamic> json) {
    return AnimeExternalLink(
      name: (json['name'] ?? '').toString().trim(),
      url: (json['url'] ?? '').toString(),
    );
  }
}

final class AnimeRelatedItem {
  const AnimeRelatedItem({
    required this.title,
    required this.session,
    required this.image,
    required this.type,
    required this.episodes,
    required this.status,
    required this.season,
  });

  final String title;
  final String session;
  final String image;
  final String type;
  final String episodes;
  final String status;
  final String season;

  factory AnimeRelatedItem.fromJson(Map<String, dynamic> json) {
    return AnimeRelatedItem(
      title: (json['title'] ?? '').toString(),
      session: (json['session'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      episodes: (json['episodes'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      season: (json['season'] ?? '').toString(),
    );
  }
}

final class AnimeRecommendation {
  const AnimeRecommendation({
    required this.title,
    required this.url,
    required this.session,
    required this.image,
    required this.type,
    required this.episodes,
    required this.status,
    required this.season,
  });

  final String title;
  final String url;
  final String session;
  final String image;
  final String type;
  final String episodes;
  final String status;
  final String season;

  factory AnimeRecommendation.fromJson(Map<String, dynamic> json) {
    final rawUrl = (json['url'] ?? '').toString();
    return AnimeRecommendation(
      title: (json['title'] ?? '').toString(),
      url: rawUrl,
      session: _sessionFromUrl(rawUrl),
      image: (json['image'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      episodes: (json['episodes'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      season: (json['season'] ?? '').toString(),
    );
  }

  static String _sessionFromUrl(String url) {
    final cleaned = url.trim();
    if (cleaned.isEmpty) return '';
    final parts = cleaned.split('/');
    return parts.isEmpty ? '' : parts.last;
  }
}

final class AnimeEpisodeRelease {
  const AnimeEpisodeRelease({
    required this.id,
    required this.episode,
    required this.episode2,
    required this.title,
    required this.snapshot,
    required this.audio,
    required this.duration,
    required this.session,
    required this.createdAt,
  });

  final String id;
  final String episode;
  final String episode2;
  final String title;
  final String snapshot;
  final String audio;
  final String duration;
  final String session;
  final String createdAt;

  factory AnimeEpisodeRelease.fromJson(Map<String, dynamic> json) {
    return AnimeEpisodeRelease(
      id: (json['id'] ?? '').toString(),
      episode: (json['episode'] ?? '').toString(),
      episode2: (json['episode2'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      snapshot: (json['snapshot'] ?? '').toString(),
      audio: (json['audio'] ?? '').toString(),
      duration: (json['duration'] ?? '').toString(),
      session: (json['session'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

final class AnimeReleasesPage {
  const AnimeReleasesPage({
    required this.releases,
    required this.currentPage,
    required this.lastPage,
  });

  final List<AnimeEpisodeRelease> releases;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;
}

final class AnimeDetails {
  const AnimeDetails({
    required this.ids,
    required this.title,
    required this.image,
    required this.preview,
    required this.synopsis,
    required this.synonym,
    required this.japanese,
    required this.type,
    required this.episodes,
    required this.status,
    required this.duration,
    required this.aired,
    required this.season,
    required this.studio,
    required this.themes,
    required this.demographic,
    required this.externalLinks,
    required this.genre,
    required this.relations,
    required this.recommendations,
  });

  final Map<String, String> ids;
  final String title;
  final String image;
  final String preview;
  final String synopsis;
  final String synonym;
  final String japanese;
  final String type;
  final String episodes;
  final String status;
  final String duration;
  final String aired;
  final String season;
  final String studio;
  final List<String> themes;
  final List<String> demographic;
  final List<AnimeExternalLink> externalLinks;
  final List<String> genre;
  final Map<String, List<AnimeRelatedItem>> relations;
  final List<AnimeRecommendation> recommendations;

  factory AnimeDetails.fromJson(Map<String, dynamic> json) {
    final idMap = <String, String>{};
    final rawIds = json['ids'];
    if (rawIds is Map<String, dynamic>) {
      for (final entry in rawIds.entries) {
        if (entry.value != null) {
          idMap[entry.key] = entry.value.toString();
        }
      }
    }

    final relations = <String, List<AnimeRelatedItem>>{};
    final rawRelations = json['relations'];
    if (rawRelations is Map<String, dynamic>) {
      for (final entry in rawRelations.entries) {
        final value = entry.value;
        if (value is List) {
          relations[entry.key] = value
              .whereType<Map<String, dynamic>>()
              .map(AnimeRelatedItem.fromJson)
              .toList();
        }
      }
    }

    return AnimeDetails(
      ids: idMap,
      title: (json['title'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      preview: (json['preview'] ?? '').toString(),
      synopsis: (json['synopsis'] ?? '').toString(),
      synonym: (json['synonym'] ?? '').toString(),
      japanese: (json['japanese'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      episodes: (json['episodes'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      duration: (json['duration'] ?? '').toString(),
      aired: (json['aired'] ?? '').toString(),
      season: (json['season'] ?? '').toString(),
      studio: (json['studio'] ?? '').toString(),
      themes: (json['themes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      demographic: (json['demographic'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      externalLinks: (json['external_links'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AnimeExternalLink.fromJson)
          .toList(),
      genre: (json['genre'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      relations: relations,
      recommendations: (json['recommendations'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AnimeRecommendation.fromJson)
          .toList(),
    );
  }
}
