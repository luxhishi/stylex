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
    this.styleTags = const [],
  });

  final String category;
  final String garmentType;
  final String primaryColor;
  final String material;
  final List<String> tags;
  final double confidence;
  final String provider;
  final String model;
  final List<String> styleTags;

  ClosetAnalysisResult copyWith({
    String? category,
    String? garmentType,
    String? primaryColor,
    String? material,
    List<String>? tags,
    List<String>? styleTags,
    double? confidence,
    String? provider,
    String? model,
  }) {
    return ClosetAnalysisResult(
      category: category ?? this.category,
      garmentType: garmentType ?? this.garmentType,
      primaryColor: primaryColor ?? this.primaryColor,
      material: material ?? this.material,
      tags: tags ?? this.tags,
      styleTags: styleTags ?? this.styleTags,
      confidence: confidence ?? this.confidence,
      provider: provider ?? this.provider,
      model: model ?? this.model,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'garment_type': garmentType,
      'primary_color': primaryColor,
      'material': material,
      'tags': tags,
      'style_tags': styleTags,
      'confidence': confidence,
      'provider': provider,
      'model': model,
    };
  }
}
