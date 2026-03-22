class ClosetAnalysisResult {
  const ClosetAnalysisResult({
    required this.category,
    required this.garmentType,
    required this.primaryColor,
    required this.material,
    required this.tags,
    required this.confidence,
    required this.provider,
    required this.model,
  });

  final String category;
  final String garmentType;
  final String primaryColor;
  final String material;
  final List<String> tags;
  final double confidence;
  final String provider;
  final String model;

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'garment_type': garmentType,
      'primary_color': primaryColor,
      'material': material,
      'tags': tags,
      'confidence': confidence,
      'provider': provider,
      'model': model,
    };
  }
}
