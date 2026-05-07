final class AiringItem {
  const AiringItem({
    required this.title,
    required this.episode,
    required this.image,
    required this.session,
  });

  final String title;
  final String episode;
  final String image;
  final String session;

  factory AiringItem.fromJson(Map<String, dynamic> json) {
    return AiringItem(
      title: (json['title'] ?? '') as String,
      episode: '${json['episode'] ?? ''}',
      image: (json['image'] ?? '') as String,
      session: (json['session'] ?? '') as String,
    );
  }
}
