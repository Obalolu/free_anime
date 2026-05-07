final class WatchSource {
  const WatchSource({
    required this.url,
    required this.embed,
    required this.resolution,
    required this.isDub,
    required this.fanSub,
  });

  final String url;
  final String embed;
  final String resolution;
  final bool isDub;
  final String fanSub;

  String get label {
    final parts = [
      if (resolution.isNotEmpty) '${resolution}p',
      isDub ? 'Dub' : 'Sub',
      if (fanSub.isNotEmpty) fanSub,
    ];
    return parts.join(' • ');
  }

  int get resolutionValue =>
      int.tryParse(resolution.replaceAll(RegExp(r'\D'), '')) ?? 0;

  factory WatchSource.fromJson(Map<String, dynamic> json) {
    return WatchSource(
      url: (json['url'] ?? '').toString(),
      embed: (json['embed'] ?? '').toString(),
      resolution: (json['resolution'] ?? '').toString(),
      isDub: json['isDub'] == true,
      fanSub: (json['fanSub'] ?? '').toString(),
    );
  }
}

final class WatchDownload {
  const WatchDownload({
    required this.resolution,
    required this.fansub,
    required this.isDub,
    required this.pahe,
    required this.download,
    required this.downloadPage,
  });

  final String resolution;
  final String fansub;
  final bool isDub;
  final String pahe;
  final String download;
  final String downloadPage;

  String get label {
    final parts = [
      if (resolution.isNotEmpty) '${resolution}p',
      isDub ? 'Dub' : 'Sub',
      if (fansub.isNotEmpty) fansub,
    ];
    return parts.join(' • ');
  }

  factory WatchDownload.fromJson(Map<String, dynamic> json) {
    return WatchDownload(
      resolution: (json['resolution'] ?? '').toString(),
      fansub: (json['fansub'] ?? '').toString(),
      isDub: json['isDub'] == true,
      pahe: (json['pahe'] ?? '').toString(),
      download: (json['download'] ?? '').toString(),
      downloadPage: (json['downloadPage'] ?? json['download_page'] ?? '')
          .toString(),
    );
  }
}

final class WatchInfo {
  const WatchInfo({
    required this.session,
    required this.provider,
    required this.episode,
    required this.animeTitle,
    required this.sources,
    required this.downloads,
  });

  final String session;
  final String provider;
  final String episode;
  final String animeTitle;
  final List<WatchSource> sources;
  final List<WatchDownload> downloads;

  WatchSource? get defaultSource {
    final validSources =
        sources.where((source) => source.url.isNotEmpty).toList()
          ..sort((a, b) => b.resolutionValue.compareTo(a.resolutionValue));
    return validSources.isEmpty ? null : validSources.first;
  }

  factory WatchInfo.fromJson(Map<String, dynamic> json) {
    return WatchInfo(
      session: (json['session'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
      episode: (json['episode'] ?? '').toString(),
      animeTitle: (json['anime_title'] ?? '').toString(),
      sources: (json['sources'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WatchSource.fromJson)
          .toList(),
      downloads: (json['downloads'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WatchDownload.fromJson)
          .where(
            (download) =>
                download.download.isNotEmpty || download.pahe.isNotEmpty,
          )
          .toList(),
    );
  }
}
