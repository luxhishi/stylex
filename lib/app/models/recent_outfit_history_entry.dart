class RecentOutfitHistoryEntry {
  const RecentOutfitHistoryEntry({
    required this.title,
    required this.itemIds,
    required this.createdAt,
    required this.source,
  });

  final String title;
  final List<String> itemIds;
  final String createdAt;
  final String source;

  factory RecentOutfitHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RecentOutfitHistoryEntry(
      title: json['title'] as String? ?? 'Recent Look',
      itemIds: ((json['item_ids'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      createdAt: json['created_at'] as String? ?? '',
      source: json['source'] as String? ?? 'home',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'item_ids': itemIds,
      'created_at': createdAt,
      'source': source,
    };
  }
}
