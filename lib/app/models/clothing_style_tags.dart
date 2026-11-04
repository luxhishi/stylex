class ClothingStyleTags {
  static const options = [
    'Casual',
    'Formal',
    'Sporty',
    'Smart Casual',
    'Streetwear',
    'Work',
    'Party',
    'Outdoor',
  ];

  static List<String> normalize(Iterable<String> tags) {
    final keys = tags
        .map((tag) => tag.trim().toLowerCase().replaceAll('-', ' '))
        .toSet();
    return options.where((tag) => keys.contains(tag.toLowerCase())).toList();
  }

  static double compatibility(List<String> a, List<String> b) {
    final first = normalize(a).toSet();
    final second = normalize(b).toSet();
    if (first.isEmpty || second.isEmpty) return 0;
    if (first.intersection(second).isNotEmpty) return 6;
    bool pair(String x, String y) =>
        (first.contains(x) && second.contains(y)) ||
        (first.contains(y) && second.contains(x));
    if (pair('Formal', 'Sporty') || pair('Formal', 'Outdoor')) return -8;
    if (pair('Smart Casual', 'Formal') ||
        pair('Smart Casual', 'Casual') ||
        pair('Work', 'Formal') ||
        pair('Work', 'Smart Casual')) {
      return 3;
    }
    if (pair('Casual', 'Sporty') ||
        pair('Casual', 'Streetwear') ||
        pair('Sporty', 'Outdoor')) {
      return 2;
    }
    return -1;
  }
}
