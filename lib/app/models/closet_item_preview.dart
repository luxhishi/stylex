class ClosetItemPreview {
  const ClosetItemPreview({
    required this.id,
    required this.imageUrl,
    required this.source,
    required this.category,
    required this.primaryColor,
    required this.material,
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });

  final String id;
  final String imageUrl;
  final String source;
  final String category;
  final String primaryColor;
  final String material;
  final String title;
  final String subtitle;
  final DateTime? createdAt;
}
