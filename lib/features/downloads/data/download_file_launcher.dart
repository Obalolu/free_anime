import 'dart:io';

import 'package:open_filex/open_filex.dart';

final class DownloadFileLauncher {
  const DownloadFileLauncher._();

  static bool hasExistingFileSync(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) return false;

    return File(normalized).existsSync();
  }

  static Future<String?> openVideo(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return 'Downloaded file is unavailable.';
    }
    if (!hasExistingFileSync(normalized)) {
      return 'Downloaded file was not found on this device.';
    }

    final result = await OpenFilex.open(normalized, type: 'video/mp4');
    if (result.type == ResultType.done) {
      return null;
    }

    final message = result.message.trim();
    if (message.isEmpty) return 'Could not open downloaded episode.';
    return 'Could not open downloaded episode: $message';
  }
}
