final class ResolvedDownloadRequest {
  const ResolvedDownloadRequest({
    required this.primaryUrl,
    required this.candidateUrls,
    required this.referer,
    required this.origin,
  });

  final String primaryUrl;
  final List<String> candidateUrls;
  final String referer;
  final String origin;

  Map<String, String> headers({int resumeFrom = 0}) {
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': referer,
      'Origin': origin,
      'Accept': '*/*',
      if (resumeFrom > 0) 'Range': 'bytes=$resumeFrom-',
    };
  }
}

final class DownloadUrlResolver {
  const DownloadUrlResolver();

  ResolvedDownloadRequest resolve({
    required String url,
    required String downloadPage,
  }) {
    final normalizedPage = downloadPage.trim();
    final referer = normalizedPage.isNotEmpty
        ? normalizedPage
        : _fallbackReferer(url);
    final origin = Uri.tryParse(referer)?.origin ?? _fallbackOrigin(url);

    final candidates = <String>[
      ..._candidateUrls(url),
      url.trim(),
    ].where((value) => value.isNotEmpty).toSet().toList();

    return ResolvedDownloadRequest(
      primaryUrl: candidates.first,
      candidateUrls: candidates,
      referer: referer,
      origin: origin,
    );
  }

  List<String> _candidateUrls(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return const [];

    final host = uri.host.toLowerCase();
    final urls = <String>[];
    if (host == 'kwik.cx' || host == 'kwik.si') {
      urls.add(uri.replace(host: 'owocdn.top').toString());
    } else if (host.endsWith('.kwik.cx') || host.endsWith('.kwik.si')) {
      urls.add(
        uri
            .replace(
              host: host.replaceAll(RegExp(r'kwik\.(cx|si)$'), 'owocdn.top'),
            )
            .toString(),
      );
    }
    return urls;
  }

  String _fallbackReferer(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'https://kwik.si/';
    return '${uri.origin}/';
  }

  String _fallbackOrigin(String url) {
    final uri = Uri.tryParse(url);
    return uri?.origin ?? 'https://kwik.si';
  }
}
