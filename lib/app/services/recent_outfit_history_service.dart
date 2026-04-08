import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/recent_outfit_history_entry.dart';

class RecentOutfitHistoryService {
  static const _historyKeyPrefix = 'stylex_recent_outfit_history_v1';
  static const _maxEntries = 12;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'guest';

  String get _storageKey => '$_historyKeyPrefix:$_currentUserId';

  Future<List<RecentOutfitHistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? const [];

    return raw
        .map((entry) {
          try {
            return RecentOutfitHistoryEntry.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<RecentOutfitHistoryEntry>()
        .toList();
  }

  Future<void> addLook({
    required String title,
    required List<String> itemIds,
    required String source,
  }) async {
    final normalizedIds = itemIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (normalizedIds.length < 2) return;

    final prefs = await SharedPreferences.getInstance();
    final existing = await loadHistory();
    final signature = normalizedIds.join('|');
    final deduped = existing.where((entry) => entry.itemIds.join('|') != signature);
    final updated = [
      RecentOutfitHistoryEntry(
        title: title.trim().isEmpty ? 'Recent Look' : title.trim(),
        itemIds: normalizedIds,
        createdAt: DateTime.now().toIso8601String(),
        source: source,
      ),
      ...deduped,
    ].take(_maxEntries).toList();

    await prefs.setStringList(
      _storageKey,
      updated.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }
}
