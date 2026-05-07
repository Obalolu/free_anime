import 'package:flutter/material.dart';

import 'package:free_anime/core/di/service_locator.dart';
import 'package:free_anime/features/watch/data/watch_models.dart';
import 'package:free_anime/features/watch/data/watch_repository.dart';
import 'package:free_anime/features/watch/presentation/player/watch_player_factories.dart';

class SourcePickerDialog extends StatefulWidget {
  const SourcePickerDialog({
    super.key,
    required this.animeSession,
    required this.episodeSession,
    this.title = 'Choose source',
  });

  final String animeSession;
  final String episodeSession;
  final String title;

  @override
  State<SourcePickerDialog> createState() => _SourcePickerDialogState();
}

class _SourcePickerDialogState extends State<SourcePickerDialog> {
  late final Future<List<WatchSource>> _sourcesFuture;

  @override
  void initState() {
    super.initState();
    _sourcesFuture = _loadSources();
  }

  Future<List<WatchSource>> _loadSources() async {
    final info = await getIt<WatchRepository>().fetchWatchInfo(
      animeSession: widget.animeSession,
      episodeSession: widget.episodeSession,
      includeDownloads: false,
    );
    return info.sources
        .where((source) => isValidWatchSourceUrl(source.url))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: FutureBuilder<List<WatchSource>>(
        future: _sourcesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return const Text('Playback sources are unavailable right now.');
          }

          final sources = snapshot.data ?? const <WatchSource>[];
          if (sources.isEmpty) {
            return const Text('No playable source is available for this episode.');
          }

          return SizedBox(
            width: 360,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: sources.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final source = sources[index];
                return ListTile(
                  title: Text(source.label),
                  onTap: () => Navigator.of(context).pop(source),
                );
              },
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
