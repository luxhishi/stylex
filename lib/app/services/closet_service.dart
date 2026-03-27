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
          title: (item['custom_name'] as String?)?.trim().isNotEmpty == true
              ? (item['custom_name'] as String).trim()
              : (analysis?['garment_type'] as String?)?.trim().isNotEmpty == true
                  ? (analysis!['garment_type'] as String).trim()
                  : 'Closet Piece',
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

    if (candidates.isEmpty) return const [];

    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.signature.compareTo(b.signature);
    });

    final index = (seed ?? 0) % candidates.length;
    return candidates[index].items;
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
              'raw_response': analysis.toJson(),
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

    try {
      await _supabase
          .from('clothing_items')
          .update({
            'custom_name': newName.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', itemId)
          .eq('user_id', user.id);
    } on PostgrestException catch (error) {
      if (_isMissingCustomNameColumn(error)) {
        throw const PostgrestException(
          message:
              'Custom clothing names are not enabled yet. Run the `20260327_clothing_custom_name.sql` migration first.',
        );
      }
      rethrow;
    }
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
