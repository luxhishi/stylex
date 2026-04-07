import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/closet_analysis_result.dart';
import '../models/closet_item_preview.dart';

class ClosetService {
  ClosetService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  static const storageBucket = 'closet-items';

  final SupabaseClient _supabase;

  Future<int> fetchItemCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    final response = await _supabase
        .from('clothing_items')
        .select('id')
        .eq('user_id', user.id);

    return response.length;
  }

  Future<List<ClosetItemPreview>> fetchClosetItems() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return const [];

    late final List<Map<String, dynamic>> itemsResponse;
    try {
      itemsResponse = await _supabase
          .from('clothing_items')
          .select('id, image_url, source, created_at, custom_name')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
    } on PostgrestException catch (error) {
      if (!_isMissingCustomNameColumn(error)) rethrow;
      itemsResponse = await _supabase
          .from('clothing_items')
          .select('id, image_url, source, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
    }

    final itemIds = itemsResponse
        .map((item) => item['id'] as String?)
        .whereType<String>()
        .toList();

    final analysisByItemId = <String, Map<String, dynamic>>{};
    if (itemIds.isNotEmpty) {
      try {
        final analysesResponse = await _supabase
            .from('clothing_ai_analyses')
            .select('clothing_item_id, raw_response, created_at')
            .inFilter('clothing_item_id', itemIds)
            .order('created_at', ascending: false);

        for (final analysis in analysesResponse) {
          final clothingItemId = analysis['clothing_item_id'] as String?;
          final rawResponse = analysis['raw_response'] as Map<String, dynamic>?;
          if (clothingItemId == null || rawResponse == null) continue;
          analysisByItemId.putIfAbsent(clothingItemId, () => rawResponse);
        }
      } on PostgrestException {
        // Keep closet previews working even if AI analysis tables are not set up yet.
      }
    }

    final previews = <ClosetItemPreview>[];

    for (final item in itemsResponse) {
      final id = item['id'] as String?;
      final rawUrl = item['image_url'] as String? ?? '';
      if (id == null || rawUrl.isEmpty) continue;

      final analysis = analysisByItemId[id];
      final resolvedUrl = await _resolvePreviewUrl(rawUrl);
      previews.add(
        ClosetItemPreview(
          id: id,
          imageUrl: resolvedUrl,
          source: item['source'] as String? ?? 'camera_upload',
          category: (analysis?['category'] as String?)?.trim().isNotEmpty == true
              ? (analysis!['category'] as String).trim()
              : _categoryForSource(item['source'] as String? ?? 'camera_upload'),
          primaryColor:
              (analysis?['primary_color'] as String?)?.trim().isNotEmpty == true
                  ? (analysis!['primary_color'] as String).trim()
                  : 'Neutral',
          material:
              (analysis?['material'] as String?)?.trim().isNotEmpty == true
                  ? (analysis!['material'] as String).trim()
                  : '',
          title: _resolvedCustomName(item, analysis) ??
              ((analysis?['garment_type'] as String?)?.trim().isNotEmpty == true
                  ? (analysis!['garment_type'] as String).trim()
                  : 'Closet Piece'),
          subtitle: (analysis?['primary_color'] as String?)?.trim().isNotEmpty ==
                  true
              ? (analysis!['primary_color'] as String).trim().toUpperCase()
              : _labelForSource(item['source'] as String? ?? 'camera_upload'),
          createdAt: DateTime.tryParse(item['created_at'] as String? ?? ''),
        ),
      );
    }

    return previews;
  }

  List<ClosetItemPreview> buildOutfitSuggestion({
    required List<ClosetItemPreview> items,
    required bool includeOuterwear,
    int? seed,
  }) {
    final candidates = _buildOutfitCandidates(
      items: items,
      includeOuterwear: includeOuterwear,
    );
    if (candidates.isEmpty) return const [];

    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.signature.compareTo(b.signature);
    });

    final index = (seed ?? 0) % candidates.length;
    return candidates[index].items;
  }

  List<List<ClosetItemPreview>> buildStyleLookbookSuggestions({
    required List<ClosetItemPreview> items,
    required String styleSlug,
    bool includeOuterwear = true,
    int count = 5,
  }) {
    final candidates = _buildOutfitCandidates(
      items: items,
      includeOuterwear: includeOuterwear,
    );
    if (candidates.isEmpty) return const [];

    final normalizedStyle = _normalizeStyleSlug(styleSlug);
    final ranked = candidates
        .map(
          (candidate) => _OutfitCandidate(
            items: candidate.items,
            score: candidate.score + _styleAffinityScore(candidate.items, normalizedStyle),
          ),
        )
        .toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return a.signature.compareTo(b.signature);
      });

    final selected = <_OutfitCandidate>[];

    for (final candidate in ranked) {
      if (selected.any((existing) => existing.signature == candidate.signature)) {
        continue;
      }
      final isDiverseEnough = selected.every(
        (existing) => _sharedItemCount(existing.items, candidate.items) <
            candidate.items.length,
      );
      if (isDiverseEnough) {
        selected.add(candidate);
      }
      if (selected.length == count) break;
    }

    if (selected.length < count) {
      for (final candidate in ranked) {
        if (selected.any((existing) => existing.signature == candidate.signature)) {
          continue;
        }
        selected.add(candidate);
        if (selected.length == count) break;
      }
    }

    return selected.map((candidate) => candidate.items).toList();
  }

  List<_OutfitCandidate> _buildOutfitCandidates({
    required List<ClosetItemPreview> items,
    required bool includeOuterwear,
  }) {
    if (items.isEmpty) return const [];

    final tops = _itemsForCategory(items, const ['top', 'tops']);
    final bottoms = _itemsForCategory(items, const ['bottom', 'bottoms']);
    final shoes = _itemsForCategory(items, const ['shoe', 'shoes']);
    final outerwear = _itemsForCategory(items, const ['outerwear']);

    if (tops.isEmpty || bottoms.isEmpty || shoes.isEmpty) {
      return const [];
    }

    final candidates = <_OutfitCandidate>[];

    for (final top in tops) {
      for (final bottom in bottoms) {
        for (final shoe in shoes) {
          final baseItems = [top, bottom, shoe];
          final baseScore =
              _scorePair(top, bottom) + _scorePair(top, shoe) + _scorePair(bottom, shoe);

          if (!includeOuterwear || outerwear.isEmpty) {
            candidates.add(
              _OutfitCandidate(
                items: baseItems,
                score: baseScore,
              ),
            );
            continue;
          }

          for (final layer in outerwear) {
            final score = baseScore +
                _scorePair(top, layer) +
                _scorePair(bottom, layer) +
                _scorePair(shoe, layer);
            candidates.add(
              _OutfitCandidate(
                items: [top, bottom, shoe, layer],
                score: score,
              ),
            );
          }
        }
      }
    }

    return candidates;
  }

  List<ClosetItemPreview> _itemsForCategory(
    List<ClosetItemPreview> items,
    List<String> accepted,
  ) {
    return items.where((item) {
      final category = item.category.trim().toLowerCase();
      return accepted.contains(category);
    }).toList();
  }

  double _scorePair(ClosetItemPreview first, ClosetItemPreview second) {
    final a = first.primaryColor.trim().toLowerCase();
    final b = second.primaryColor.trim().toLowerCase();
    final neutralColors = {
      'black',
      'white',
      'gray',
      'grey',
      'charcoal',
      'beige',
      'ivory',
      'tan',
      'cream',
      'neutral',
      'silver',
      'brown',
      'navy',
    };

    if (a == b) return 5;
    if (neutralColors.contains(a) && neutralColors.contains(b)) return 4;
    if (neutralColors.contains(a) || neutralColors.contains(b)) return 3;

    final commonGoodPairs = {
      'blue:tan',
      'tan:blue',
      'blue:white',
      'white:blue',
      'green:brown',
      'brown:green',
      'red:black',
      'black:red',
      'pink:white',
      'white:pink',
    };

    return commonGoodPairs.contains('$a:$b') ? 2 : 1;
  }

  double _styleAffinityScore(List<ClosetItemPreview> items, String styleSlug) {
    final palette = _preferredColorsForStyle(styleSlug);
    final keywords = _preferredKeywordsForStyle(styleSlug);
    var score = 0.0;

    for (final item in items) {
      final color = item.primaryColor.trim().toLowerCase();
      final title = item.title.trim().toLowerCase();
      final category = item.category.trim().toLowerCase();

      if (palette.contains(color)) {
        score += 2.3;
      }
      if (keywords.any(title.contains)) {
        score += 1.8;
      }

      if (styleSlug == 'minimalist' &&
          {'top', 'tops', 'bottom', 'bottoms', 'shoe'}.contains(category)) {
        score += 0.5;
      }
      if (styleSlug == 'formal' &&
          {'outerwear', 'shoe', 'bottom', 'bottoms'}.contains(category)) {
        score += 0.7;
      }
      if (styleSlug == 'streetwear' &&
          {'outerwear', 'shoe', 'top', 'tops'}.contains(category)) {
        score += 0.7;
      }
      if (styleSlug == 'bohemian' &&
          {'outerwear', 'top', 'tops'}.contains(category)) {
        score += 0.6;
      }
      if (styleSlug == 'classic-vintage' &&
          {'outerwear', 'shoe', 'top', 'tops'}.contains(category)) {
        score += 0.65;
      }
    }

    return score;
  }

  Set<String> _preferredColorsForStyle(String styleSlug) {
    switch (styleSlug) {
      case 'streetwear':
        return {
          'black',
          'charcoal',
          'gray',
          'blue',
          'green',
          'white',
        };
      case 'formal':
        return {
          'black',
          'charcoal',
          'gray',
          'navy',
          'white',
          'blue',
        };
      case 'bohemian':
        return {
          'tan',
          'beige',
          'brown',
          'green',
          'pink',
          'ivory',
          'cream',
        };
      case 'classic-vintage':
        return {
          'brown',
          'tan',
          'beige',
          'green',
          'navy',
          'charcoal',
          'ivory',
        };
      case 'minimalist':
      default:
        return {
          'black',
          'white',
          'gray',
          'charcoal',
          'beige',
          'tan',
          'neutral',
          'blue',
          'ivory',
          'cream',
          'brown',
        };
    }
  }

  List<String> _preferredKeywordsForStyle(String styleSlug) {
    switch (styleSlug) {
      case 'streetwear':
        return ['hoodie', 'sneaker', 'cargo', 'bomber', 'oversized', 'boot'];
      case 'formal':
        return ['blazer', 'trouser', 'loafer', 'shirt', 'dress', 'coat'];
      case 'bohemian':
        return ['linen', 'flow', 'knit', 'woven', 'boot', 'cardigan'];
      case 'classic-vintage':
        return ['vintage', 'heritage', 'coat', 'loafer', 'boot', 'polo'];
      case 'minimalist':
      default:
        return ['tee', 'shirt', 'polo', 'coat', 'trouser', 'boot', 'sneaker'];
    }
  }

  String _normalizeStyleSlug(String styleSlug) {
    final trimmed = styleSlug.trim().toLowerCase();
    return trimmed.isEmpty ? 'minimalist' : trimmed;
  }

  int _sharedItemCount(
    List<ClosetItemPreview> first,
    List<ClosetItemPreview> second,
  ) {
    final firstIds = first.map((item) => item.id).toSet();
    return second.where((item) => firstIds.contains(item.id)).length;
  }

  Future<void> addClosetItem({
    required String imagePath,
    required String source,
    required String customName,
    ClosetAnalysisResult? analysis,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Please log in again before adding to your closet.');
    }

    final extension = _extensionForPath(imagePath);
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${user.id.substring(0, 8)}.$extension';
    final storagePath = '${user.id}/$fileName';

    await _supabase.storage.from(storageBucket).upload(
          storagePath,
          File(imagePath),
          fileOptions: const FileOptions(upsert: false),
        );

    final now = DateTime.now().toUtc().toIso8601String();

    final insertPayload = {
      'user_id': user.id,
      'image_url': storagePath,
      'custom_name': customName.trim(),
      'status': 'draft',
      'source': source,
      'ai_processed': analysis != null,
      'is_confirmed': false,
      'created_at': now,
      'updated_at': now,
    };

    late final Map<String, dynamic> inserted;
    try {
      inserted = await _supabase
          .from('clothing_items')
          .insert(insertPayload)
          .select('id')
          .single();
    } on PostgrestException catch (error) {
      if (!_isMissingCustomNameColumn(error)) rethrow;
      final fallbackPayload = Map<String, dynamic>.from(insertPayload)
        ..remove('custom_name');
      inserted = await _supabase
          .from('clothing_items')
          .insert(fallbackPayload)
          .select('id')
          .single();
    }

    await _supabase.from('clothing_item_images').insert({
      'clothing_item_id': inserted['id'],
      'image_url': storagePath,
      'image_type': 'original',
      'sort_order': 0,
      'created_at': now,
    });

    if (analysis != null) {
      try {
        final savedAnalysis = await _supabase
            .from('clothing_ai_analyses')
            .insert({
              'clothing_item_id': inserted['id'],
              'provider': analysis.provider,
              'model': analysis.model,
              'raw_response':
                  _analysisRawResponse(analysis, customName: customName),
              'confidence_score': analysis.confidence,
              'created_at': now,
            })
            .select('id')
            .single();

        final predictions = <Map<String, dynamic>>[
          {
            'analysis_id': savedAnalysis['id'],
            'field_name': 'category',
            'predicted_slug': analysis.category.toLowerCase().replaceAll(' ', '-'),
            'predicted_label': analysis.category,
            'confidence_score': analysis.confidence,
          },
          {
            'analysis_id': savedAnalysis['id'],
            'field_name': 'type',
            'predicted_slug':
                analysis.garmentType.toLowerCase().replaceAll(' ', '-'),
            'predicted_label': analysis.garmentType,
            'confidence_score': analysis.confidence,
          },
          {
            'analysis_id': savedAnalysis['id'],
            'field_name': 'primary_color',
            'predicted_slug':
                analysis.primaryColor.toLowerCase().replaceAll(' ', '-'),
            'predicted_label': analysis.primaryColor,
            'confidence_score': analysis.confidence,
          },
          {
            'analysis_id': savedAnalysis['id'],
            'field_name': 'material',
            'predicted_slug': analysis.material.toLowerCase().replaceAll(' ', '-'),
            'predicted_label': analysis.material,
            'confidence_score': analysis.confidence,
          },
        ];

        await _supabase.from('clothing_ai_predictions').insert(predictions);
      } on PostgrestException {
        // Keep the closet save successful even if optional AI tables are missing.
      }
    }
  }

  Future<void> renameClosetItem({
    required String itemId,
    required String newName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Please log in again before renaming your item.');
    }

    final normalizedName = newName.trim();
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      await _supabase
          .from('clothing_items')
          .update({
            'custom_name': normalizedName,
            'updated_at': now,
          })
          .eq('id', itemId)
          .eq('user_id', user.id);
    } on PostgrestException catch (error) {
      if (!_isMissingCustomNameColumn(error)) rethrow;
      await _supabase
          .from('clothing_items')
          .update({
            'updated_at': now,
          })
          .eq('id', itemId)
          .eq('user_id', user.id);
    }

    await _persistCustomNameFallback(
      itemId: itemId,
      customName: normalizedName,
      now: now,
    );
  }

  Future<void> updateClosetItem({
    required String itemId,
    required String newName,
    required String category,
    required String primaryColor,
    required String material,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Please log in again before editing your item.');
    }

    final normalizedName = newName.trim();
    final normalizedCategory = category.trim();
    final normalizedColor = primaryColor.trim();
    final normalizedMaterial = material.trim();
    final now = DateTime.now().toUtc().toIso8601String();
    var customNamePersistedInColumn = true;

    try {
      await _supabase
          .from('clothing_items')
          .update({
            'custom_name': normalizedName,
            'updated_at': now,
          })
          .eq('id', itemId)
          .eq('user_id', user.id);
    } on PostgrestException catch (error) {
      if (!_isMissingCustomNameColumn(error)) rethrow;
      customNamePersistedInColumn = false;
      await _supabase
          .from('clothing_items')
          .update({
            'updated_at': now,
          })
          .eq('id', itemId)
          .eq('user_id', user.id);
    }

    final updatedAnalysis = ClosetAnalysisResult(
      category: normalizedCategory,
      garmentType: normalizedCategory,
      primaryColor: normalizedColor,
      material: normalizedMaterial,
      tags: _updatedTagsForType(
        const [],
        normalizedCategory,
      ),
      confidence: 1,
      provider: 'manual-edit',
      model: 'manual',
    );

    try {
      final existingAnalysis = await _supabase
          .from('clothing_ai_analyses')
          .select('id, provider, model, confidence_score, raw_response')
          .eq('clothing_item_id', itemId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (existingAnalysis == null) {
        final insertedAnalysis = await _supabase
            .from('clothing_ai_analyses')
            .insert({
              'clothing_item_id': itemId,
              'provider': updatedAnalysis.provider,
              'model': updatedAnalysis.model,
              'raw_response': _analysisRawResponse(
                updatedAnalysis,
                customName: normalizedName,
              ),
              'confidence_score': updatedAnalysis.confidence,
              'created_at': now,
            })
            .select('id')
            .single();

        await _syncPredictionsForAnalysis(
          analysisId: insertedAnalysis['id'] as String,
          analysis: updatedAnalysis,
        );
        return;
      }

      final existingRaw = Map<String, dynamic>.from(
        existingAnalysis['raw_response'] as Map<String, dynamic>? ?? const {},
      );
      final mergedAnalysis = ClosetAnalysisResult(
        category: normalizedCategory,
        garmentType: normalizedCategory,
        primaryColor: normalizedColor,
        material: normalizedMaterial,
        tags: _updatedTagsForType(
          (existingRaw['tags'] as List<dynamic>? ?? const [])
              .map((tag) => tag.toString())
              .toList(),
          normalizedCategory,
        ),
        confidence:
            (existingAnalysis['confidence_score'] as num?)?.toDouble() ?? 1,
        provider: (existingAnalysis['provider'] as String?)?.trim().isNotEmpty ==
                true
            ? (existingAnalysis['provider'] as String).trim()
            : updatedAnalysis.provider,
        model: (existingAnalysis['model'] as String?)?.trim().isNotEmpty == true
            ? (existingAnalysis['model'] as String).trim()
            : updatedAnalysis.model,
      );

      await _supabase
          .from('clothing_ai_analyses')
          .update({
            'raw_response': {
              ...existingRaw,
              ..._analysisRawResponse(
                mergedAnalysis,
                customName:
                    customNamePersistedInColumn ? normalizedName : normalizedName,
              ),
            },
          })
          .eq('id', existingAnalysis['id'] as String);

      await _syncPredictionsForAnalysis(
        analysisId: existingAnalysis['id'] as String,
        analysis: mergedAnalysis,
      );
    } on PostgrestException {
      // Keep manual edits working for the main clothing record even if optional AI tables are unavailable.
    }
  }

  Future<void> _persistCustomNameFallback({
    required String itemId,
    required String customName,
    required String now,
  }) async {
    try {
      final existingAnalysis = await _supabase
          .from('clothing_ai_analyses')
          .select('id, raw_response')
          .eq('clothing_item_id', itemId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (existingAnalysis == null) {
        await _supabase.from('clothing_ai_analyses').insert({
          'clothing_item_id': itemId,
          'provider': 'manual-edit',
          'model': 'manual',
          'raw_response': {
            'custom_name': customName,
          },
          'confidence_score': 1,
          'created_at': now,
        });
        return;
      }

      final existingRaw = Map<String, dynamic>.from(
        existingAnalysis['raw_response'] as Map<String, dynamic>? ?? const {},
      );
      await _supabase
          .from('clothing_ai_analyses')
          .update({
            'raw_response': {
              ...existingRaw,
              'custom_name': customName,
            },
          })
          .eq('id', existingAnalysis['id'] as String);
    } on PostgrestException {
      // Keep rename/edit working even if AI analysis tables are unavailable.
    }
  }

  Map<String, dynamic> _analysisRawResponse(
    ClosetAnalysisResult analysis, {
    String? customName,
  }) {
    return {
      ...analysis.toJson(),
      if (customName != null && customName.trim().isNotEmpty)
        'custom_name': customName.trim(),
    };
  }

  String? _resolvedCustomName(
    Map<String, dynamic> item,
    Map<String, dynamic>? analysis,
  ) {
    final columnName = (item['custom_name'] as String?)?.trim();
    if (columnName != null && columnName.isNotEmpty) {
      return columnName;
    }

    final analysisName = (analysis?['custom_name'] as String?)?.trim();
    if (analysisName != null && analysisName.isNotEmpty) {
      return analysisName;
    }

    return null;
  }

  Future<void> deleteClosetItem({required String itemId}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Please log in again before deleting your item.');
    }

    String? storagePath;
    try {
      final itemResponse = await _supabase
          .from('clothing_items')
          .select('image_url')
          .eq('id', itemId)
          .eq('user_id', user.id)
          .maybeSingle();
      storagePath = _storagePathFromValue(
        itemResponse?['image_url'] as String? ?? '',
      );
    } on PostgrestException {
      // Continue deleting related rows even if we cannot fetch the storage path.
    }

    try {
      final analyses = await _supabase
          .from('clothing_ai_analyses')
          .select('id')
          .eq('clothing_item_id', itemId);
      final analysisIds = analyses
          .map((analysis) => analysis['id'] as String?)
          .whereType<String>()
          .toList();
      if (analysisIds.isNotEmpty) {
        await _supabase
            .from('clothing_ai_predictions')
            .delete()
            .inFilter('analysis_id', analysisIds);
      }
      await _supabase
          .from('clothing_ai_analyses')
          .delete()
          .eq('clothing_item_id', itemId);
    } on PostgrestException {
      // These optional AI tables may not exist yet.
    }

    try {
      await _supabase
          .from('clothing_item_images')
          .delete()
          .eq('clothing_item_id', itemId);
    } on PostgrestException {
      // Keep deletion working even if the images table is unavailable.
    }

    await _supabase
        .from('clothing_items')
        .delete()
        .eq('id', itemId)
        .eq('user_id', user.id);

    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await _supabase.storage.from(storageBucket).remove([storagePath]);
      } on StorageException {
        // The database delete should still succeed even if the storage file was already missing.
      }
    }
  }

  Future<void> _syncPredictionsForAnalysis({
    required String analysisId,
    required ClosetAnalysisResult analysis,
  }) async {
    try {
      await _supabase
          .from('clothing_ai_predictions')
          .delete()
          .eq('analysis_id', analysisId);

      await _supabase.from('clothing_ai_predictions').insert([
        {
          'analysis_id': analysisId,
          'field_name': 'category',
          'predicted_slug': analysis.category.toLowerCase().replaceAll(' ', '-'),
          'predicted_label': analysis.category,
          'confidence_score': analysis.confidence,
        },
        {
          'analysis_id': analysisId,
          'field_name': 'type',
          'predicted_slug':
              analysis.garmentType.toLowerCase().replaceAll(' ', '-'),
          'predicted_label': analysis.garmentType,
          'confidence_score': analysis.confidence,
        },
        {
          'analysis_id': analysisId,
          'field_name': 'primary_color',
          'predicted_slug':
              analysis.primaryColor.toLowerCase().replaceAll(' ', '-'),
          'predicted_label': analysis.primaryColor,
          'confidence_score': analysis.confidence,
        },
        {
          'analysis_id': analysisId,
          'field_name': 'material',
          'predicted_slug': analysis.material.toLowerCase().replaceAll(' ', '-'),
          'predicted_label': analysis.material,
          'confidence_score': analysis.confidence,
        },
      ]);
    } on PostgrestException {
      // Prediction tables are optional for the current app experience.
    }
  }

  List<String> _updatedTagsForType(List<String> tags, String type) {
    const typeOptions = ['top', 'bottom', 'shoe', 'outerwear'];
    final typeTag = type.trim().toLowerCase();
    final slugTag = typeTag.replaceAll(' ', '-');
    final filtered = tags.where((tag) {
      final normalized = tag.trim().toLowerCase();
      return !typeOptions.contains(normalized) &&
          !typeOptions.map((option) => option.replaceAll(' ', '-')).contains(normalized);
    }).toList();

    return [
      typeTag,
      if (slugTag != typeTag) slugTag,
      ...filtered,
    ];
  }

  String _extensionForPath(String path) {
    final sanitized = path.split('?').first;
    final dotIndex = sanitized.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == sanitized.length - 1) {
      return 'jpg';
    }

    return sanitized.substring(dotIndex + 1).toLowerCase();
  }

  Future<String> _resolvePreviewUrl(String rawUrl) async {
    final storagePath = _storagePathFromValue(rawUrl);
    if (storagePath == null) return rawUrl;

    try {
      return await _supabase.storage
          .from(storageBucket)
          .createSignedUrl(storagePath, 60 * 60);
    } on StorageException {
      return _looksLikeUrl(rawUrl)
          ? rawUrl
          : _supabase.storage.from(storageBucket).getPublicUrl(storagePath);
    }
  }

  String? _storagePathFromValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (!_looksLikeUrl(trimmed)) {
      return trimmed;
    }

    final marker = '/$storageBucket/';
    final index = trimmed.indexOf(marker);
    if (index == -1) return null;

    final path = trimmed.substring(index + marker.length);
    return path.isEmpty ? null : path.split('?').first;
  }

  bool _looksLikeUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  bool _isMissingCustomNameColumn(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('custom_name') &&
        (message.contains('schema cache') || message.contains('column'));
  }

  String _labelForSource(String source) {
    switch (source) {
      case 'gallery_upload':
        return 'UPLOADED';
      case 'camera_upload':
        return 'CAPTURED';
      default:
        return 'CLOSET ITEM';
    }
  }

  String _categoryForSource(String source) {
    switch (source) {
      case 'camera_upload':
      case 'gallery_upload':
        return 'Tops';
      default:
        return 'All Items';
    }
  }
}

class _OutfitCandidate {
  const _OutfitCandidate({
    required this.items,
    required this.score,
  });

  final List<ClosetItemPreview> items;
  final double score;

  String get signature => items.map((item) => item.id).join('|');
}
