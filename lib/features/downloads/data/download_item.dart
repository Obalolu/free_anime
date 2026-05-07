enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

final class DownloadItem {
  const DownloadItem({
    required this.id,
    this.animeSession = '',
    this.episodeSession = '',
    required this.animeTitle,
    this.animePoster = '',
    required this.episode,
    this.episodeLabel = '',
    this.episodeSnapshot = '',
    required this.resolution,
    required this.fansub,
    required this.isDub,
    required this.url,
    this.candidateUrls = const [],
    this.downloadPage = '',
    this.referer = '',
    this.origin = '',
    required this.filename,
    required this.createdAt,
    this.filePath = '',
    this.partialFilePath = '',
    this.progress = 0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.resumeBytes = 0,
    this.speedBytesPerSecond = 0,
    this.etaSeconds = 0,
    this.status = DownloadStatus.queued,
    this.error = '',
  });

  final String id;
  final String animeSession;
  final String episodeSession;
  final String animeTitle;
  final String animePoster;
  final String episode;
  final String episodeLabel;
  final String episodeSnapshot;
  final String resolution;
  final String fansub;
  final bool isDub;
  final String url;
  final List<String> candidateUrls;
  final String downloadPage;
  final String referer;
  final String origin;
  final String filename;
  final String filePath;
  final String partialFilePath;
  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final int resumeBytes;
  final double speedBytesPerSecond;
  final int etaSeconds;
  final DownloadStatus status;
  final String error;
  final DateTime createdAt;

  bool get isActive =>
      status == DownloadStatus.queued ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.paused;

  bool get canResume =>
      status == DownloadStatus.paused ||
      (status == DownloadStatus.failed && resumeBytes > 0);

  bool get isCompleted => status == DownloadStatus.completed;

  bool get hasOfflineFile => isCompleted && filePath.trim().isNotEmpty;

  String get normalizedAnimeSession => animeSession.trim();

  String get normalizedEpisodeSession => episodeSession.trim();

  String get animeGroupingKey {
    final session = normalizedAnimeSession;
    if (session.isNotEmpty) return session;

    final title = animeTitle.trim();
    return title.isEmpty ? id : title;
  }

  String get displayEpisodeLabel {
    final label = episodeLabel.trim();
    if (label.isNotEmpty) return label;

    final rawEpisode = episode.trim();
    if (rawEpisode.isNotEmpty) return 'Episode $rawEpisode';

    return 'Episode';
  }

  bool matchesIdentity(DownloadItem other) {
    if (normalizedAnimeSession.isNotEmpty &&
        normalizedEpisodeSession.isNotEmpty &&
        other.normalizedAnimeSession.isNotEmpty &&
        other.normalizedEpisodeSession.isNotEmpty) {
      return normalizedAnimeSession == other.normalizedAnimeSession &&
          normalizedEpisodeSession == other.normalizedEpisodeSession;
    }

    return animeTitle.trim() == other.animeTitle.trim() &&
        displayEpisodeLabel == other.displayEpisodeLabel;
  }

  bool matchesVariant(DownloadItem other) {
    return resolution.trim() == other.resolution.trim() &&
        fansub.trim() == other.fansub.trim() &&
        isDub == other.isDub;
  }

  DownloadItem copyWith({
    String? animeSession,
    String? episodeSession,
    String? animePoster,
    String? episodeLabel,
    String? episodeSnapshot,
    String? url,
    List<String>? candidateUrls,
    String? downloadPage,
    String? referer,
    String? origin,
    String? filePath,
    String? partialFilePath,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    int? resumeBytes,
    double? speedBytesPerSecond,
    int? etaSeconds,
    DownloadStatus? status,
    String? error,
  }) {
    return DownloadItem(
      id: id,
      animeSession: animeSession ?? this.animeSession,
      episodeSession: episodeSession ?? this.episodeSession,
      animeTitle: animeTitle,
      animePoster: animePoster ?? this.animePoster,
      episode: episode,
      episodeLabel: episodeLabel ?? this.episodeLabel,
      episodeSnapshot: episodeSnapshot ?? this.episodeSnapshot,
      resolution: resolution,
      fansub: fansub,
      isDub: isDub,
      url: url ?? this.url,
      candidateUrls: candidateUrls ?? this.candidateUrls,
      downloadPage: downloadPage ?? this.downloadPage,
      referer: referer ?? this.referer,
      origin: origin ?? this.origin,
      filename: filename,
      filePath: filePath ?? this.filePath,
      partialFilePath: partialFilePath ?? this.partialFilePath,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      resumeBytes: resumeBytes ?? this.resumeBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'animeSession': animeSession,
      'episodeSession': episodeSession,
      'animeTitle': animeTitle,
      'animePoster': animePoster,
      'episode': episode,
      'episodeLabel': episodeLabel,
      'episodeSnapshot': episodeSnapshot,
      'resolution': resolution,
      'fansub': fansub,
      'isDub': isDub,
      'url': url,
      'candidateUrls': candidateUrls,
      'downloadPage': downloadPage,
      'referer': referer,
      'origin': origin,
      'filename': filename,
      'filePath': filePath,
      'partialFilePath': partialFilePath,
      'progress': progress,
      'receivedBytes': receivedBytes,
      'totalBytes': totalBytes,
      'resumeBytes': resumeBytes,
      'speedBytesPerSecond': speedBytesPerSecond,
      'etaSeconds': etaSeconds,
      'status': status.name,
      'error': error,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: (json['id'] ?? '').toString(),
      animeSession: (json['animeSession'] ?? '').toString(),
      episodeSession: (json['episodeSession'] ?? '').toString(),
      animeTitle: (json['animeTitle'] ?? '').toString(),
      animePoster: (json['animePoster'] ?? '').toString(),
      episode: (json['episode'] ?? '').toString(),
      episodeLabel: (json['episodeLabel'] ?? '').toString(),
      episodeSnapshot: (json['episodeSnapshot'] ?? '').toString(),
      resolution: (json['resolution'] ?? '').toString(),
      fansub: (json['fansub'] ?? '').toString(),
      isDub: json['isDub'] == true,
      url: (json['url'] ?? '').toString(),
      candidateUrls: (json['candidateUrls'] as List<dynamic>? ?? const [])
          .map((value) => '$value')
          .toList(),
      downloadPage: (json['downloadPage'] ?? '').toString(),
      referer: (json['referer'] ?? '').toString(),
      origin: (json['origin'] ?? '').toString(),
      filename: (json['filename'] ?? '').toString(),
      filePath: (json['filePath'] ?? '').toString(),
      partialFilePath: (json['partialFilePath'] ?? '').toString(),
      progress: double.tryParse((json['progress'] ?? '0').toString()) ?? 0,
      receivedBytes:
          int.tryParse((json['receivedBytes'] ?? '0').toString()) ?? 0,
      totalBytes: int.tryParse((json['totalBytes'] ?? '0').toString()) ?? 0,
      resumeBytes: int.tryParse((json['resumeBytes'] ?? '0').toString()) ?? 0,
      speedBytesPerSecond:
          double.tryParse((json['speedBytesPerSecond'] ?? '0').toString()) ?? 0,
      etaSeconds: int.tryParse((json['etaSeconds'] ?? '0').toString()) ?? 0,
      status: DownloadStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => DownloadStatus.failed,
      ),
      error: (json['error'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
