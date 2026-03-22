import 'dart:async';
import 'dart:io';

import 'package:image/image.dart' as img;

import '../models/closet_analysis_result.dart';

class ClosetAnalysisService {
  Future<ClosetAnalysisResult> analyzeImage({
    required String imagePath,
    required String source,
  }) async {
    try {
      return await _analyzeLocally(
        imagePath: imagePath,
        source: source,
      );
    } catch (_) {
      // Fall back to filename-style guesses if local image parsing fails.
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));

    final lowerPath = imagePath.toLowerCase();

    final garmentType = _detectType(lowerPath);
    final color = _detectColor(lowerPath);
    final material = _detectMaterial(lowerPath, garmentType);
    final category =
        garmentType == 'Unclassified' ? 'Needs Vision API' : garmentType;
    final tags = <String>[
      garmentType.toLowerCase(),
      color.toLowerCase(),
      material.toLowerCase(),
      if (source == 'camera_upload') 'captured' else 'uploaded',
    ];

    return ClosetAnalysisResult(
      category: category,
      garmentType: garmentType,
      primaryColor: color,
      material: material,
      tags: tags,
      confidence: 0.86,
      provider: 'local-fallback',
      model: 'stylex-local-v1',
    );
  }

  Future<ClosetAnalysisResult> _analyzeLocally({
    required String imagePath,
    required String source,
  }) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Image could not be decoded.');
    }

    final resized = decoded.width > 220
        ? img.copyResize(decoded, width: 220)
        : decoded;
    final mask = _buildForegroundMask(resized);
    final bounds = _findBounds(mask);
    if (bounds == null) {
      throw const FormatException('No foreground garment was detected.');
    }

    final features = _extractFeatures(mask, bounds);
    final garmentType = _classifyGarment(features);
    final category = garmentType;
    final primaryColor = _detectColorFromPixels(resized, mask, bounds);
    final material = _detectMaterialFromType(garmentType);
    final tags = <String>[
      garmentType.toLowerCase().replaceAll(' ', '-'),
      primaryColor.toLowerCase().replaceAll(' ', '-'),
      material.toLowerCase().replaceAll(' ', '-'),
      category.toLowerCase(),
      if (source == 'camera_upload') 'captured' else 'uploaded',
    ];
    final confidence = _confidenceForType(garmentType);

    return ClosetAnalysisResult(
      category: category,
      garmentType: garmentType,
      primaryColor: primaryColor,
      material: material,
      tags: tags,
      confidence: confidence,
      provider: 'local-image-analyzer',
      model: 'stylex-local-v2',
    );
  }

  List<List<bool>> _buildForegroundMask(img.Image image) {
    final background = _estimateBackground(image);
    final mask = List.generate(
      image.height,
      (_) => List<bool>.filled(image.width, false),
    );

    for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final distance = _colorDistance(
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
            background.$1,
            background.$2,
            background.$3,
        );
        mask[y][x] = distance > 32;
      }
    }

    return mask;
  }

  (int, int, int) _estimateBackground(img.Image image) {
    final samples = <(int, int, int)>[];
    final sampleSize = 12;
    final corners = [
      (0, 0),
      (image.width - sampleSize, 0),
      (0, image.height - sampleSize),
      (image.width - sampleSize, image.height - sampleSize),
    ];

    for (final (startX, startY) in corners) {
      for (var y = startY.clamp(0, image.height - 1);
          y < (startY + sampleSize).clamp(0, image.height);
          y++) {
        for (var x = startX.clamp(0, image.width - 1);
            x < (startX + sampleSize).clamp(0, image.width);
            x++) {
          final pixel = image.getPixel(x, y);
          samples.add((
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
          ));
        }
      }
    }

    final avgR =
        samples.map((sample) => sample.$1).reduce((a, b) => a + b) ~/ samples.length;
    final avgG =
        samples.map((sample) => sample.$2).reduce((a, b) => a + b) ~/ samples.length;
    final avgB =
        samples.map((sample) => sample.$3).reduce((a, b) => a + b) ~/ samples.length;
    return (avgR, avgG, avgB);
  }

  _Bounds? _findBounds(List<List<bool>> mask) {
    int? left;
    int? top;
    int? right;
    int? bottom;

    for (var y = 0; y < mask.length; y++) {
      for (var x = 0; x < mask[y].length; x++) {
        if (!mask[y][x]) continue;
        left = left == null ? x : (x < left ? x : left);
        top = top == null ? y : (y < top ? y : top);
        right = right == null ? x : (x > right ? x : right);
        bottom = bottom == null ? y : (y > bottom ? y : bottom);
      }
    }

    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }

    return _Bounds(left: left, top: top, right: right, bottom: bottom);
  }

  _GarmentFeatures _extractFeatures(List<List<bool>> mask, _Bounds bounds) {
    final width = bounds.width.toDouble();
    final height = bounds.height.toDouble();
    final rowFractions = [0.12, 0.24, 0.45, 0.65, 0.82];
    final widths = rowFractions
        .map((fraction) => _rowCoverage(mask, bounds, fraction))
        .toList();
    final segments = rowFractions
        .map((fraction) => _rowSegments(mask, bounds, fraction))
        .toList();
    final areaRatio = _foregroundArea(mask, bounds) / (width * height);

    return _GarmentFeatures(
      aspectRatio: height / width,
      topWidth: widths[0],
      upperWidth: widths[1],
      midWidth: widths[2],
      lowerWidth: widths[3],
      bottomWidth: widths[4],
      lowerSegments: segments[3],
      bottomSegments: segments[4],
      areaRatio: areaRatio,
    );
  }

  double _rowCoverage(List<List<bool>> mask, _Bounds bounds, double fraction) {
    final y = bounds.top + ((bounds.height - 1) * fraction).round();
    var count = 0;
    for (var x = bounds.left; x <= bounds.right; x++) {
      if (mask[y][x]) count++;
    }
    return count / bounds.width;
  }

  int _rowSegments(List<List<bool>> mask, _Bounds bounds, double fraction) {
    final y = bounds.top + ((bounds.height - 1) * fraction).round();
    var segments = 0;
    var inSegment = false;
    for (var x = bounds.left; x <= bounds.right; x++) {
      final active = mask[y][x];
      if (active && !inSegment) {
        segments++;
        inSegment = true;
      } else if (!active) {
        inSegment = false;
      }
    }
    return segments;
  }

  int _foregroundArea(List<List<bool>> mask, _Bounds bounds) {
    var count = 0;
    for (var y = bounds.top; y <= bounds.bottom; y++) {
      for (var x = bounds.left; x <= bounds.right; x++) {
        if (mask[y][x]) count++;
      }
    }
    return count;
  }

  String _classifyGarment(_GarmentFeatures f) {
    if (f.aspectRatio > 1.32 &&
        f.topWidth > f.midWidth * 1.10 &&
        f.upperWidth > f.bottomWidth * 1.08 &&
        f.areaRatio > 0.44) {
      return 'Outerwear';
    }

    if (f.bottomSegments >= 2 && f.aspectRatio > 1.35) {
      return 'Bottom';
    }

    if (f.aspectRatio < 1.35 &&
        f.bottomSegments == 1 &&
        f.bottomWidth > f.upperWidth * 1.18 &&
        f.lowerWidth > f.midWidth * 1.08) {
      return 'Shoe';
    }

    if (f.aspectRatio < 0.95 &&
        f.bottomSegments == 1 &&
        f.bottomWidth > 0.78) {
      return 'Shoe';
    }

    if (f.aspectRatio > 1.18 &&
        f.topWidth > f.midWidth * 1.12 &&
        f.upperWidth > f.bottomWidth * 1.06) {
      return 'Top';
    }

    if (f.aspectRatio > 1.0 &&
        f.bottomSegments >= 2 &&
        f.bottomWidth > 0.35) {
      return 'Bottom';
    }

    return 'Top';
  }

  String _detectColorFromPixels(
    img.Image image,
    List<List<bool>> mask,
    _Bounds bounds,
  ) {
    var totalR = 0;
    var totalG = 0;
    var totalB = 0;
    var count = 0;

    for (var y = bounds.top; y <= bounds.bottom; y++) {
      for (var x = bounds.left; x <= bounds.right; x++) {
        if (!mask[y][x]) continue;
        final pixel = image.getPixel(x, y);
        totalR += pixel.r.toInt();
        totalG += pixel.g.toInt();
        totalB += pixel.b.toInt();
        count++;
      }
    }

    if (count == 0) return 'Neutral';

    final r = totalR ~/ count;
    final g = totalG ~/ count;
    final b = totalB ~/ count;
    final maxValue = [r, g, b].reduce((a, c) => a > c ? a : c);
    final minValue = [r, g, b].reduce((a, c) => a < c ? a : c);

    if (maxValue < 55) return 'Black';
    if (minValue > 210) return 'White';
    if ((r - g).abs() < 12 && (g - b).abs() < 12) {
      if (maxValue < 110) return 'Charcoal';
      if (maxValue < 170) return 'Gray';
      return 'Silver';
    }
    if (r > g + 25 && r > b + 25) return 'Red';
    if (g > r + 18 && g > b + 18) return 'Green';
    if (b > r + 18 && b > g + 18) return 'Blue';
    if (r > 165 && g > 145 && b < 120) return 'Tan';
    if (r > 185 && g > 175 && b > 140) return 'Beige';
    if (r > 140 && b > 120) return 'Pink';
    return 'Neutral';
  }

  String _detectMaterialFromType(String type) {
    switch (type) {
      case 'Shoe':
        return 'Leather';
      case 'Outerwear':
        return 'Structured Blend';
      case 'Bottom':
        return 'Woven Blend';
      case 'Top':
        return 'Cotton Blend';
      default:
        return 'Textile Blend';
    }
  }

  double _confidenceForType(String type) {
    switch (type) {
      case 'Bottom':
      case 'Shoe':
        return 0.82;
      case 'Outerwear':
      case 'Top':
        return 0.74;
      default:
        return 0.62;
    }
  }

  int _colorDistance(int r1, int g1, int b1, int r2, int g2, int b2) {
    final dr = r1 - r2;
    final dg = g1 - g2;
    final db = b1 - b2;
    return (dr * dr + dg * dg + db * db);
  }

  String _detectType(String path) {
    if (path.contains('blazer') ||
        path.contains('jacket') ||
        path.contains('coat') ||
        path.contains('hoodie')) {
      return 'Outerwear';
    }
    if (path.contains('jean') || path.contains('denim') || path.contains('trouser') || path.contains('pant')) {
      return 'Bottom';
    }
    if (path.contains('sneaker') || path.contains('shoe') || path.contains('boot')) {
      return 'Shoe';
    }
    if (path.contains('shirt') ||
        path.contains('tee') ||
        path.contains('polo') ||
        path.contains('crewneck') ||
        path.contains('crew-neck') ||
        path.contains('sweater') ||
        path.contains('knit')) {
      return 'Top';
    }
    return 'Top';
  }

  String _detectColor(String path) {
    if (path.contains('black')) return 'Black';
    if (path.contains('white')) return 'White';
    if (path.contains('ivory') || path.contains('cream') || path.contains('beige')) {
      return 'Ivory';
    }
    if (path.contains('blue') || path.contains('navy')) return 'Blue';
    if (path.contains('brown') || path.contains('tan')) return 'Brown';
    if (path.contains('green') || path.contains('olive')) return 'Green';
    if (path.contains('pink')) return 'Pink';
    if (path.contains('gray') || path.contains('grey')) return 'Gray';
    return 'Neutral';
  }

  String _detectMaterial(String path, String type) {
    if (path.contains('linen')) return 'Linen Blend';
    if (path.contains('wool')) return 'Wool';
    if (path.contains('denim')) return 'Denim';
    if (path.contains('cotton')) return 'Cotton';
    if (path.contains('leather')) return 'Leather';
    if (type == 'Blazer' || type == 'Coat') return 'Structured Blend';
    return 'Cotton Blend';
  }

}

class _Bounds {
  const _Bounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left + 1;
  int get height => bottom - top + 1;
}

class _GarmentFeatures {
  const _GarmentFeatures({
    required this.aspectRatio,
    required this.topWidth,
    required this.upperWidth,
    required this.midWidth,
    required this.lowerWidth,
    required this.bottomWidth,
    required this.lowerSegments,
    required this.bottomSegments,
    required this.areaRatio,
  });

  final double aspectRatio;
  final double topWidth;
  final double upperWidth;
  final double midWidth;
  final double lowerWidth;
  final double bottomWidth;
  final int lowerSegments;
  final int bottomSegments;
  final double areaRatio;
}
