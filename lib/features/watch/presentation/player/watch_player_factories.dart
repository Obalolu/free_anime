import 'package:better_player_enhanced/better_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:free_anime/core/theme/app_theme.dart';
import 'package:free_anime/features/watch/data/watch_models.dart';

final class WatchPlayerConfigurationFactory {
  const WatchPlayerConfigurationFactory();

  BetterPlayerConfiguration build({
    required Widget? placeholder,
    required void Function(BetterPlayerEvent event) onEvent,
    required Widget Function(BuildContext context, String? errorMessage)
    errorBuilder,
    Widget Function(
      BetterPlayerController controller,
      Function(bool) onPlayerVisibilityChanged,
    )?
    customControlsBuilder,
    bool enablePip = false,
    List<BetterPlayerOverflowMenuItem> overflowMenuCustomItems =
        const <BetterPlayerOverflowMenuItem>[],
  }) {
    final playerTheme = customControlsBuilder == null
        ? BetterPlayerTheme.material
        : BetterPlayerTheme.custom;
    return BetterPlayerConfiguration(
      autoPlay: true,
      looping: false,
      fit: BoxFit.contain,
      aspectRatio: 16 / 9,
      fullScreenByDefault: false,
      autoDetectFullscreenAspectRatio: true,
      autoDetectFullscreenDeviceOrientation: true,
      handleLifecycle: true,
      autoDispose: false,
      expandToFill: false,
      placeholder: placeholder,
      showPlaceholderUntilPlay: true,
      errorBuilder: errorBuilder,
      eventListener: onEvent,
      controlsConfiguration: BetterPlayerControlsConfiguration(
        playerTheme: playerTheme,
        customControlsBuilder: customControlsBuilder,
        showControlsOnInitialize: true,
        enablePip: enablePip,
        enableSubtitles: true,
        enableQualities: true,
        enableAudioTracks: true,
        enableRetry: true,
        enableProgressBarDrag: true,
        enablePlaybackSpeed: true,
        enableOverflowMenu: true,
        progressBarPlayedColor: AppTheme.primary,
        progressBarHandleColor: AppTheme.primary,
        progressBarBufferedColor: AppTheme.primarySoft,
        progressBarBackgroundColor: Color(0x66FFFFFF),
        controlBarColor: Color(0xAA0F0F14),
        textColor: Colors.white,
        iconsColor: Colors.white,
        overflowMenuIconsColor: Colors.black,
        overflowModalColor: Colors.white,
        overflowModalTextColor: Colors.black,
        loadingColor: AppTheme.primary,
        controlsHideTime: const Duration(seconds: 5),
        controlBarHeight: 56,
        overflowMenuCustomItems: overflowMenuCustomItems,
        forwardSkipTimeInMilliseconds: 10000,
        backwardSkipTimeInMilliseconds: 10000,
      ),
    );
  }
}

final class WatchPlayerDataSourceFactory {
  const WatchPlayerDataSourceFactory();

  BetterPlayerDataSource build({
    required WatchSource selectedSource,
    required List<WatchSource> allSources,
    required Map<String, String> headers,
    required Widget? placeholder,
  }) {
    return BetterPlayerDataSource.network(
      selectedSource.url,
      headers: headers,
      placeholder: placeholder,
      useAsmsTracks: true,
      useAsmsAudioTracks: true,
      useAsmsSubtitles: true,
      videoFormat: _inferVideoFormat(selectedSource.url),
    );
  }

  BetterPlayerVideoFormat _inferVideoFormat(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return BetterPlayerVideoFormat.hls;
    if (lower.contains('.mpd')) return BetterPlayerVideoFormat.dash;
    if (lower.contains('.ism') || lower.contains('manifest')) {
      return BetterPlayerVideoFormat.ss;
    }
    return BetterPlayerVideoFormat.other;
  }
}

bool isValidWatchSourceUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}

Widget? buildWatchPlaceholder(String imageUrl) {
  if (imageUrl.trim().isEmpty) return null;
  return DecoratedBox(
    decoration: const BoxDecoration(color: Color(0xFF111118)),
    child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
  );
}
