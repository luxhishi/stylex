import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/closet_item_preview.dart';
import '../models/recent_outfit_history_entry.dart';
import '../services/closet_service.dart';
import '../services/recent_outfit_history_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/onboarding_shell.dart';
import 'closet_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class OutfitsScreen extends StatefulWidget {
  const OutfitsScreen({super.key});

  @override
  State<OutfitsScreen> createState() => _OutfitsScreenState();
}

class _OutfitsScreenState extends State<OutfitsScreen> {
  static const _savedOutfitsKeyPrefix = 'stylex_saved_outfits_v2';
  static const _plannedOutfitsKeyPrefix = 'stylex_planned_outfits_v1';
  static const _filters = ['All Items', 'Tops', 'Bottoms', 'Shoes', 'Layers'];
  static const _outfitTagSuggestions = [
    'Casual',
    'Smart Casual',
    'Formal',
    'Minimalist',
    'Streetwear',
    'Work',
    'Weekend',
    'Travel',
    'Date Night',
    'Classic Vintage',
    'Bohemian',
  ];

  final ClosetService _closetService = ClosetService();
  final RecentOutfitHistoryService _recentHistoryService =
      RecentOutfitHistoryService();
  List<ClosetItemPreview> _closetItems = const [];
  List<_SavedOutfit> _savedOutfits = const [];
  List<RecentOutfitHistoryEntry> _recentHistory = const [];
  ClosetItemPreview? _selectedTop;
  ClosetItemPreview? _selectedBottom;
  ClosetItemPreview? _selectedShoe;
  ClosetItemPreview? _selectedLayer;
  var _selectedFilter = 'All Items';
  var _selectedSavedLookTag = 'All';
  var _isLoading = true;
  var _isSaving = false;
  late DateTime _plannerMonth;
  Map<String, _PlannedEvent> _plannedEventsByDate = const {};

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'guest';

  String get _savedOutfitsKey => '$_savedOutfitsKeyPrefix:$_currentUserId';
  String get _plannedOutfitsKey => '$_plannedOutfitsKeyPrefix:$_currentUserId';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _plannerMonth = DateTime(now.year, now.month);
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadClosetItems(),
      _loadSavedOutfits(),
      _loadPlannedOutfits(),
      _loadRecentHistory(),
    ]);
  }

  Future<void> _loadClosetItems() async {
    try {
      final items = await _closetService.fetchClosetItems();
      if (!mounted) return;
      setState(() {
        _closetItems = items;
        _selectedTop = _retainIfPresent(_selectedTop, items);
        _selectedBottom = _retainIfPresent(_selectedBottom, items);
        _selectedShoe = _retainIfPresent(_selectedShoe, items);
        _selectedLayer = _retainIfPresent(_selectedLayer, items);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _closetItems = const [];
        _selectedTop = null;
        _selectedBottom = null;
        _selectedShoe = null;
        _selectedLayer = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedOutfits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_savedOutfitsKey) ?? const [];
    final parsed = raw
        .map((entry) {
          try {
            return _SavedOutfit.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<_SavedOutfit>()
        .toList();

    if (!mounted) return;
    setState(() {
      _savedOutfits = _sortSavedOutfits(parsed);
      if (!_savedLookTags.contains(_selectedSavedLookTag)) {
        _selectedSavedLookTag = 'All';
      }
    });
  }

  Future<void> _loadRecentHistory() async {
    final history = await _recentHistoryService.loadHistory();
    if (!mounted) return;
    setState(() {
      _recentHistory = history;
    });
  }

  Future<void> _persistSavedOutfits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _savedOutfitsKey,
      _savedOutfits.map((outfit) => jsonEncode(outfit.toJson())).toList(),
    );
    HomeScreen.clearSessionCache();
  }

  List<_SavedOutfit> _sortSavedOutfits(Iterable<_SavedOutfit> outfits) {
    final sorted = outfits.toList();
    sorted.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  Future<void> _loadPlannedOutfits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_plannedOutfitsKey);

    if (raw == null || raw.isEmpty) {
      if (!mounted) return;
      setState(() => _plannedEventsByDate = const {});
      return;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _plannedEventsByDate = decoded.map(
          (key, value) => MapEntry(
            key,
            value is String
                ? _PlannedEvent(outfitId: value)
                : _PlannedEvent.fromJson(value as Map<String, dynamic>),
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _plannedEventsByDate = const {});
    }
  }

  Future<void> _persistPlannedOutfits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _plannedOutfitsKey,
      jsonEncode(
        _plannedEventsByDate.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      ),
    );
    HomeScreen.clearSessionCache();
  }

  ClosetItemPreview? _retainIfPresent(
    ClosetItemPreview? item,
    List<ClosetItemPreview> source,
  ) {
    if (item == null) return null;

    for (final candidate in source) {
      if (candidate.id == item.id) {
        return candidate;
      }
    }

    return null;
  }

  List<ClosetItemPreview> get _filteredItems {
    if (_selectedFilter == 'All Items') return _closetItems;

    return _closetItems.where((item) {
      final category = item.category.trim().toLowerCase();
      switch (_selectedFilter) {
        case 'Tops':
          return category == 'top' || category == 'tops';
        case 'Bottoms':
          return category == 'bottom' || category == 'bottoms';
        case 'Shoes':
          return category == 'shoe' || category == 'shoes';
        case 'Layers':
          return category == 'outerwear';
        default:
          return true;
      }
    }).toList();
  }

  bool get _hasCurrentOutfit =>
      _selectedTop != null ||
      _selectedBottom != null ||
      _selectedShoe != null ||
      _selectedLayer != null;

  List<ClosetItemPreview> get _currentOutfitItems => [
        _selectedTop,
        _selectedBottom,
        _selectedShoe,
        _selectedLayer,
      ].whereType<ClosetItemPreview>().toList();

  List<String> get _savedLookTags {
    final tags = <String>[];
    final seen = <String>{};
    for (final outfit in _savedOutfits) {
      for (final tag in outfit.tags) {
        final key = tag.toLowerCase();
        if (seen.add(key)) {
          tags.add(tag);
        }
      }
    }
    tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      'All',
      if (_savedOutfits.any((outfit) => outfit.isFavorite)) 'Favorites',
      ...tags,
    ];
  }

  List<_SavedOutfit> get _visibleSavedOutfits {
    if (_selectedSavedLookTag == 'All') return _savedOutfits;
    if (_selectedSavedLookTag == 'Favorites') {
      return _savedOutfits.where((outfit) => outfit.isFavorite).toList();
    }
    final selectedKey = _selectedSavedLookTag.toLowerCase();
    return _savedOutfits.where((outfit) {
      return outfit.tags.any((tag) => tag.toLowerCase() == selectedKey);
    }).toList();
  }

  String get _savedLooksEmptyMessage {
    if (_selectedSavedLookTag == 'Favorites') {
      return 'You have not favorited any looks yet.';
    }
    return 'No saved looks match this tag yet.';
  }

  List<_RecentLookBundle> get _visibleRecentHistory {
    return _recentHistory
        .map((entry) {
          final items = entry.itemIds
              .map((id) {
                for (final item in _closetItems) {
                  if (item.id == id) return item;
                }
                return null;
              })
              .whereType<ClosetItemPreview>()
              .toList();
          if (items.length < 2) return null;
          return _RecentLookBundle(entry: entry, items: items);
        })
        .whereType<_RecentLookBundle>()
        .toList();
  }

  Future<void> _generateOutfit() async {
    if (_closetItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some closet items first.')),
      );
      return;
    }

    final suggestion = _closetService.buildOutfitSuggestion(
      items: _closetItems,
      includeOuterwear: true,
    );

    if (suggestion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We need at least a top, bottom, and shoe to generate a look.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedTop = _findByCategories(suggestion, const ['top', 'tops']);
      _selectedBottom = _findByCategories(
        suggestion,
        const ['bottom', 'bottoms'],
      );
      _selectedShoe = _findByCategories(suggestion, const ['shoe', 'shoes']);
      _selectedLayer = _findByCategories(suggestion, const ['outerwear']);
    });
  }

  ClosetItemPreview? _findByCategories(
    List<ClosetItemPreview> items,
    List<String> accepted,
  ) {
    for (final item in items) {
      if (accepted.contains(item.category.trim().toLowerCase())) {
        return item;
      }
    }
    return null;
  }

  void _assignItem(ClosetItemPreview item) {
    final category = item.category.trim().toLowerCase();

    setState(() {
      if (category == 'top' || category == 'tops') {
        _selectedTop = _selectedTop?.id == item.id ? null : item;
      } else if (category == 'bottom' || category == 'bottoms') {
        _selectedBottom = _selectedBottom?.id == item.id ? null : item;
      } else if (category == 'shoe' || category == 'shoes') {
        _selectedShoe = _selectedShoe?.id == item.id ? null : item;
      } else if (category == 'outerwear') {
        _selectedLayer = _selectedLayer?.id == item.id ? null : item;
      } else if (_selectedTop == null) {
        _selectedTop = item;
      } else if (_selectedBottom == null) {
        _selectedBottom = item;
      } else if (_selectedShoe == null) {
        _selectedShoe = item;
      } else {
        _selectedLayer = item;
      }
    });
  }

  void _applyOutfitItems(List<ClosetItemPreview> items) {
    setState(() {
      _selectedTop = _findByCategories(items, const ['top', 'tops']);
      _selectedBottom = _findByCategories(items, const ['bottom', 'bottoms']);
      _selectedShoe = _findByCategories(items, const ['shoe', 'shoes']);
      _selectedLayer = _findByCategories(items, const ['outerwear']);
    });
  }

  void _removeAssignedItem(ClosetItemPreview item) {
    final category = item.category.trim().toLowerCase();
    setState(() {
      if (category == 'top' || category == 'tops') {
        if (_selectedTop?.id == item.id) _selectedTop = null;
      } else if (category == 'bottom' || category == 'bottoms') {
        if (_selectedBottom?.id == item.id) _selectedBottom = null;
      } else if (category == 'shoe' || category == 'shoes') {
        if (_selectedShoe?.id == item.id) _selectedShoe = null;
      } else if (category == 'outerwear') {
        if (_selectedLayer?.id == item.id) _selectedLayer = null;
      }
    });
  }

  void _clearCurrentOutfit() {
    setState(() {
      _selectedTop = null;
      _selectedBottom = null;
      _selectedShoe = null;
      _selectedLayer = null;
    });
  }

  Future<void> _saveCurrentOutfit() async {
    final pieces = [
      _selectedTop,
      _selectedBottom,
      _selectedShoe,
      _selectedLayer,
    ].whereType<ClosetItemPreview>().toList();

    if (pieces.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Build a look with at least two pieces before saving.'),
        ),
      );
      return;
    }

    final draft = await _showSaveOutfitSheet(pieces);
    if (draft == null) return;

    setState(() => _isSaving = true);

    try {
      final outfit = _SavedOutfit(
        name: draft.name,
        itemIds: pieces.map((item) => item.id).toList(),
        tags: draft.tags,
        isFavorite: false,
        createdAt: DateTime.now().toIso8601String(),
      );
      setState(() {
        _savedOutfits = _sortSavedOutfits([outfit, ..._savedOutfits]);
        if (!_savedLookTags.contains(_selectedSavedLookTag)) {
          _selectedSavedLookTag = 'All';
        }
      });
      await _persistSavedOutfits();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outfit saved to your atelier.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  List<ClosetItemPreview> _resolveSavedOutfitItems(_SavedOutfit outfit) {
    return outfit.itemIds
        .map((id) {
          for (final item in _closetItems) {
            if (item.id == id) return item;
          }
          return null;
        })
        .whereType<ClosetItemPreview>()
        .toList();
  }

  void _restoreSavedOutfit(_SavedOutfit outfit) {
    final items = _resolveSavedOutfitItems(outfit);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some pieces in this saved outfit are no longer available.'),
        ),
      );
      return;
    }

    _applyOutfitItems(items);
  }

  void _applyRecentLook(_RecentLookBundle bundle) {
    _applyOutfitItems(bundle.items);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${bundle.entry.title} is now in your workspace.')),
    );
  }

  Future<void> _updateSavedOutfit(
    _SavedOutfit outfit, {
    required String newName,
    required List<String> newTags,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    final normalizedTags = _normalizeTags(newTags);
    setState(() {
      _savedOutfits = _sortSavedOutfits(
        _savedOutfits.map((saved) => saved.createdAt == outfit.createdAt
            ? saved.copyWith(name: trimmed, tags: normalizedTags)
            : saved),
      );
      if (!_savedLookTags.contains(_selectedSavedLookTag)) {
        _selectedSavedLookTag = 'All';
      }
    });
    await _persistSavedOutfits();
  }

  Future<void> _setSavedOutfitFavorite(
    _SavedOutfit outfit, {
    required bool isFavorite,
  }) async {
    setState(() {
      _savedOutfits = _sortSavedOutfits(
        _savedOutfits.map((saved) => saved.createdAt == outfit.createdAt
            ? saved.copyWith(isFavorite: isFavorite)
            : saved),
      );
      if (!_savedLookTags.contains(_selectedSavedLookTag)) {
        _selectedSavedLookTag = 'All';
      }
    });
    await _persistSavedOutfits();
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  DateTime _startOfCalendarGrid(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month);
    final offset = firstDayOfMonth.weekday % 7;
    return firstDayOfMonth.subtract(Duration(days: offset));
  }

  List<DateTime> _calendarDaysForMonth(DateTime month) {
    final start = _startOfCalendarGrid(month);
    return List<DateTime>.generate(
      42,
      (index) => DateTime(start.year, start.month, start.day + index),
    );
  }

  _SavedOutfit? _savedOutfitById(String id) {
    for (final outfit in _savedOutfits) {
      if (outfit.createdAt == id) {
        return outfit;
      }
    }
    return null;
  }

  _PlannedEvent? _plannedEventForDate(DateTime date) {
    return _plannedEventsByDate[_dateKey(date)];
  }

  _SavedOutfit? _plannedOutfitForDate(DateTime date) {
    final plannedEvent = _plannedEventForDate(date);
    if (plannedEvent == null) return null;
    return _savedOutfitById(plannedEvent.outfitId);
  }

  Future<void> _scheduleOutfitForDate({
    required _SavedOutfit outfit,
    required DateTime date,
    required String eventTitle,
    required String eventNotes,
  }) async {
    final key = _dateKey(date);
    setState(() {
      _plannedEventsByDate = {
        ..._plannedEventsByDate,
        key: _PlannedEvent(
          outfitId: outfit.createdAt,
          eventTitle: eventTitle.trim(),
          eventNotes: eventNotes.trim(),
        ),
      };
      _plannerMonth = DateTime(date.year, date.month);
    });
    await _persistPlannedOutfits();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${outfit.name} saved for ${_formatReadableDate(date)}.',
        ),
      ),
    );
  }

  Future<void> _removePlannedOutfit(DateTime date) async {
    final key = _dateKey(date);
    if (!_plannedEventsByDate.containsKey(key)) return;

    final updated = Map<String, _PlannedEvent>.from(_plannedEventsByDate)
      ..remove(key);
    setState(() => _plannedEventsByDate = updated);
    await _persistPlannedOutfits();
  }

  Future<_SavedOutfitDraft?> _showSaveOutfitSheet(
    List<ClosetItemPreview> pieces,
  ) async {
    return showModalBottomSheet<_SavedOutfitDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SaveOutfitSheet(
          pieces: pieces,
          initialName: 'Look ${_savedOutfits.length + 1}',
          initialTags: _suggestTagsForOutfit(pieces),
          tagSuggestions: _outfitTagSuggestions,
          normalizeTags: _normalizeTags,
        );
      },
    );
  }

  List<String> _suggestTagsForOutfit(List<ClosetItemPreview> items) {
    final titles = items.map((item) => item.title.toLowerCase()).join(' ');
    final colors = items.map((item) => item.primaryColor.toLowerCase()).toList();
    const neutralColors = {
      'black',
      'white',
      'gray',
      'grey',
      'charcoal',
      'beige',
      'tan',
      'neutral',
      'ivory',
      'cream',
      'brown',
      'blue',
      'navy',
    };

    final tags = <String>[];
    if (RegExp(r'blazer|trouser|loafer|coat|shirt').hasMatch(titles)) {
      tags.add('Formal');
    } else {
      tags.add('Casual');
    }
    if (items.isNotEmpty &&
        colors.every((color) => neutralColors.contains(color))) {
      tags.add('Minimalist');
    }
    if (RegExp(r'hoodie|sneaker|cargo|bomber|boot').hasMatch(titles)) {
      tags.add('Streetwear');
    }
    return _normalizeTags(tags);
  }

  List<String> _normalizeTags(Iterable<String> tags) {
    final normalized = <String>[];
    final seen = <String>{};

    for (final rawTag in tags) {
      final trimmed = rawTag.trim();
      if (trimmed.isEmpty) continue;
      final formatted = trimmed
          .split(RegExp(r'\s+'))
          .map((word) {
            if (word.isEmpty) return word;
            return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
          })
          .join(' ');
      final key = formatted.toLowerCase();
      if (seen.add(key)) {
        normalized.add(formatted);
      }
    }

    return normalized;
  }

  Future<void> _pickDateForOutfit(_SavedOutfit outfit) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: today,
      lastDate: DateTime(now.year + 3, 12, 31),
    );

    if (picked == null || !mounted) return;
    await _scheduleOutfitForDate(
      outfit: outfit,
      date: picked,
      eventTitle: '',
      eventNotes: '',
    );
  }

  Future<void> _showPlannerDaySheet(DateTime date) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDate = DateTime(date.year, date.month, date.day);
    final isPastDate = selectedDate.isBefore(todayDate);
    final plannedEvent = _plannedEventForDate(date);
    final result = await showModalBottomSheet<_PlannerDaySheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PlannerDaySheet(
          date: date,
          isPastDate: isPastDate,
          initialEvent: plannedEvent,
          savedOutfits: _savedOutfits,
          resolveOutfit: _savedOutfitById,
          resolveItems: _resolveSavedOutfitItems,
          formatReadableDate: _formatReadableDate,
        );
      },
    );

    if (!mounted || result == null) return;
    if (result.removeEvent) {
      await _removePlannedOutfit(date);
      return;
    }

    final selectedOutfit = _savedOutfitById(result.outfitId ?? '');
    if (selectedOutfit == null) return;
    await _scheduleOutfitForDate(
      outfit: selectedOutfit,
      date: date,
      eventTitle: result.eventTitle,
      eventNotes: result.eventNotes,
    );
  }

  String _formatReadableDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[date.month - 1];
  }

  Future<void> _showSavedLookDetails(_SavedOutfit outfit) async {
    final items = _resolveSavedOutfitItems(outfit);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some pieces in this saved outfit are no longer available.'),
        ),
      );
      return;
    }

    final controller = TextEditingController(text: outfit.name);
    var selectedTags = List<String>.from(outfit.tags);
    var isFavorite = outfit.isFavorite;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final media = MediaQuery.of(context);
        final keyboardInset = media.viewInsets.bottom;
        final availableHeight = math.max(
          0.0,
          media.size.height - keyboardInset - media.padding.top - 28,
        );
        final maxHeight = math.min(
          media.size.height * 0.82,
          availableHeight,
        );

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 14,
                  right: 14,
                  bottom: keyboardInset + 14,
                  top: keyboardInset > 0 ? 20 : 60,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD8E5E1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isFavorite
                                ? 'Favorite Look'
                                : 'Saved Look Details',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF203032),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final nextValue = !isFavorite;
                                setModalState(() => isFavorite = nextValue);
                                await _setSavedOutfitFavorite(
                                  outfit,
                                  isFavorite: nextValue,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isFavorite
                                    ? const Color(0xFFD05D79)
                                    : const Color(0xFF0A7A76),
                                side: BorderSide(
                                  color: isFavorite
                                      ? const Color(0xFFF0CFD8)
                                      : const Color(0xFFCFE4DE),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 18,
                              ),
                              label: Text(
                                isFavorite
                                    ? 'Favorited'
                                    : 'Mark as Favorite',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: 'Look name',
                              filled: true,
                              fillColor: const Color(0xFFF3F8F7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Tags',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF203032),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _outfitTagSuggestions.map((tag) {
                              final selected = selectedTags.contains(tag);
                              return FilterChip(
                                label: Text(tag),
                                selected: selected,
                                showCheckmark: false,
                                onSelected: (_) {
                                  setModalState(() {
                                    if (selected) {
                                      selectedTags = selectedTags
                                          .where((item) => item != tag)
                                          .toList();
                                    } else {
                                      selectedTags =
                                          _normalizeTags([...selectedTags, tag]);
                                    }
                                  });
                                },
                                backgroundColor: const Color(0xFFF2F8F7),
                                selectedColor: const Color(0xFFDFF4EF),
                                side: BorderSide(
                                  color: selected
                                      ? const Color(0xFF0A7A76)
                                      : const Color(0xFFDCE7E4),
                                ),
                                labelStyle: TextStyle(
                                  color: selected
                                      ? const Color(0xFF0A7A76)
                                      : const Color(0xFF6B7B7D),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 220,
                            child: GridView.builder(
                              itemCount: items.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.9,
                              ),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return _SavedLookDetailCard(item: item);
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _pickDateForOutfit(outfit);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFDFF4EF),
                                foregroundColor: const Color(0xFF0A7A76),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              icon: const Icon(Icons.calendar_month_rounded, size: 18),
                              label: const Text('Save To Date'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final newName = controller.text;
                                    final newTags = List<String>.from(selectedTags);
                                    Navigator.of(context).pop();
                                    await _updateSavedOutfit(
                                      outfit,
                                      newName: newName,
                                      newTags: newTags,
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0A7A76),
                                    side: const BorderSide(color: Color(0xFFCFE4DE)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: const Text('Save Changes'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    _restoreSavedOutfit(outfit);
                                    Navigator.of(context).pop();
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0A7A76),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: const Text('Use This Look'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  void _handleTabSelection(AppTab tab) {
    if (tab == AppTab.outfits) return;

    if (tab == AppTab.home) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
      return;
    }

    if (tab == AppTab.closet) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ClosetScreen()),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tab.name} is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = Supabase.instance.client.auth.currentUser;
    final displayName = _resolveDisplayName(currentUser);

    return Scaffold(
      body: AppViewport(
        child: AppPanel(
          padding: EdgeInsets.zero,
          borderRadius: 0,
          clip: true,
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OutfitHeader(
                      displayName: displayName,
                      onMenuPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'WORKSPACE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF9DAAAC),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Outfit Atelier',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        height: 0.96,
                        letterSpacing: -1.6,
                        color: const Color(0xFF213133),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _hasCurrentOutfit ? _clearCurrentOutfit : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF5B6B6D),
                              side: const BorderSide(color: Color(0xFFD4E2DE)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            icon: const Icon(Icons.layers_clear_rounded, size: 18),
                            label: const Text('Clear'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _saveCurrentOutfit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0A7A76),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.bookmark_rounded, size: 18),
                            label: const Text('Save Outfit'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SoftPanel(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Your Closet',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF233234),
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.tune_rounded,
                                size: 18,
                                color: Color(0xFF8EA0A2),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 34,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _filters.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final filter = _filters[index];
                                final selected = filter == _selectedFilter;
                                return ChoiceChip(
                                  label: Text(filter),
                                  selected: selected,
                                  showCheckmark: false,
                                  onSelected: (_) {
                                    setState(() => _selectedFilter = filter);
                                  },
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF7C8D90),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  backgroundColor: const Color(0xFFEAF3F1),
                                  selectedColor: const Color(0xFF0A7A76),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                    side: BorderSide(
                                      color: selected
                                          ? const Color(0xFF0A7A76)
                                          : const Color(0xFFDCE9E5),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF0A7A76),
                                ),
                              ),
                            )
                          else if (_filteredItems.isEmpty)
                            const _EmptyClosetPrompt()
                          else
                            GridView.builder(
                              itemCount: _filteredItems.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.72,
                              ),
                              itemBuilder: (context, index) {
                                final item = _filteredItems[index];
                                final selected = [
                                  _selectedTop?.id,
                                  _selectedBottom?.id,
                                  _selectedShoe?.id,
                                  _selectedLayer?.id,
                                ].contains(item.id);
                                return _ClosetSelectionCard(
                                  item: item,
                                  selected: selected,
                                  onTap: () => _assignItem(item),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD9EEFF), Color(0xFFEFF8FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Color(0xFF267DA7),
                                    size: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'STYLE AI',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF287CA5),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _hasCurrentOutfit
                                  ? 'You are building a look'
                                  : 'Stuck on a look?',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF1E4960),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Let our AI stylist suggest a complete outfit based on your closet palette and wardrobe balance.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF5A7890),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _generateOutfit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF20465C),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: const Text('Generate AI Outfit'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_visibleRecentHistory.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SoftPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent Looks',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF233234),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Looks you chose from Home show up here so you can reuse them quickly.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF6F8082),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 158,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _visibleRecentHistory.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final look = _visibleRecentHistory[index];
                                  return _RecentLookCard(
                                    bundle: look,
                                    onTap: () => _applyRecentLook(look),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_hasCurrentOutfit) ...[
                      const SizedBox(height: 16),
                      _SoftPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Look',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF233234),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _currentOutfitItems
                                  .map(
                                    (item) => _CurrentLookChip(
                                      item: item,
                                      onRemove: () => _removeAssignedItem(item),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_savedOutfits.isNotEmpty)
                      _SoftPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saved Looks',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF233234),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_savedLookTags.length > 1) ...[
                              SizedBox(
                                height: 34,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _savedLookTags.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final tag = _savedLookTags[index];
                                    final selected = tag == _selectedSavedLookTag;
                                    return ChoiceChip(
                                      label: Text(tag),
                                      selected: selected,
                                      showCheckmark: false,
                                      onSelected: (_) {
                                        setState(() {
                                          _selectedSavedLookTag = tag;
                                        });
                                      },
                                      labelStyle: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFF7C8D90),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      backgroundColor: const Color(0xFFEAF3F1),
                                      selectedColor: const Color(0xFF0A7A76),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(9),
                                        side: BorderSide(
                                          color: selected
                                              ? const Color(0xFF0A7A76)
                                              : const Color(0xFFDCE9E5),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_visibleSavedOutfits.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  _savedLooksEmptyMessage,
                                  style: const TextStyle(
                                    color: Color(0xFF7D8D90),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                height: 132,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _visibleSavedOutfits.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final saved = _visibleSavedOutfits[index];
                                    final items = _resolveSavedOutfitItems(saved);
                                    return _SavedLookCard(
                                      outfit: saved,
                                      items: items,
                                      onTap: () => _showSavedLookDetails(saved),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    _SoftPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Outfit Calendar',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF233234),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _plannerMonth = DateTime(
                                      _plannerMonth.year,
                                      _plannerMonth.month - 1,
                                    );
                                  });
                                },
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 28,
                                  height: 28,
                                ),
                                icon: const Icon(Icons.chevron_left_rounded),
                                color: const Color(0xFF6E8082),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${_monthLabel(_plannerMonth)} ${_plannerMonth.year}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF233234),
                                ),
                              ),
                              const SizedBox(width: 2),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _plannerMonth = DateTime(
                                      _plannerMonth.year,
                                      _plannerMonth.month + 1,
                                    );
                                  });
                                },
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 28,
                                  height: 28,
                                ),
                                icon: const Icon(Icons.chevron_right_rounded),
                                color: const Color(0xFF6E8082),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LayoutBuilder(
                              builder: (context, constraints) {
                                final crossAxisSpacing =
                                    constraints.maxWidth < 360 ? 4.0 : 6.0;
                                final cellWidth =
                                    (constraints.maxWidth - (crossAxisSpacing * 6)) / 7;
                                final cellHeight = math.max(
                                  36.0,
                                  math.min(48.0, cellWidth * 0.82),
                                );

                                return Column(
                                  children: [
                                    const Row(
                                      children: [
                                        Expanded(child: _PlannerWeekdayLabel(label: 'Sun')),
                                        Expanded(child: _PlannerWeekdayLabel(label: 'Mon')),
                                        Expanded(child: _PlannerWeekdayLabel(label: 'Tue')),
                                        Expanded(child: _PlannerWeekdayLabel(label: 'Wed')),
                                        Expanded(child: _PlannerWeekdayLabel(label: 'Thu')),
                                        Expanded(child: _PlannerWeekdayLabel(label: 'Fri')),
                                        Expanded(child: _PlannerWeekdayLabel(label: 'Sat')),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    GridView.builder(
                                      itemCount: _calendarDaysForMonth(_plannerMonth).length,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 7,
                                        crossAxisSpacing: crossAxisSpacing,
                                        mainAxisSpacing: crossAxisSpacing,
                                        mainAxisExtent: cellHeight,
                                      ),
                                      itemBuilder: (context, index) {
                                        final date =
                                            _calendarDaysForMonth(_plannerMonth)[index];
                                        final now = DateTime.now();
                                        final todayDate =
                                            DateTime(now.year, now.month, now.day);
                                        final selectedDate =
                                            DateTime(date.year, date.month, date.day);
                                        final plannedEvent = _plannedEventForDate(date);
                                        final plannedOutfit = _plannedOutfitForDate(date);
                                        return _PlannerDayCard(
                                          date: date,
                                          currentMonth: _plannerMonth,
                                          eventTitle: plannedEvent?.eventTitle,
                                          plannedOutfitName: plannedOutfit?.name,
                                          isEditable: !selectedDate.isBefore(todayDate),
                                          onTap: () => _showPlannerDaySheet(date),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: StylexBottomNav(
                  selectedTab: AppTab.outfits,
                  onTabSelected: _handleTabSelection,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveDisplayName(User? user) {
    final fullName =
        (user?.userMetadata?['full_name'] as String?)?.trim() ?? '';
    if (fullName.isNotEmpty) {
      return fullName;
    }

    final email = user?.email?.trim() ?? '';
    if (email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'S';
  }
}

class _OutfitHeader extends StatelessWidget {
  const _OutfitHeader({
    required this.displayName,
    required this.onMenuPressed,
  });

  final String displayName;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final initials = displayName.isEmpty ? 'S' : displayName[0].toUpperCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5F2),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A7A76),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Row(
          children: [
            IconButton(
              onPressed: onMenuPressed,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0A7A76),
                minimumSize: const Size(38, 38),
              ),
              icon: const Icon(Icons.menu_rounded, size: 18),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'STYLEX',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF0A7A76),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFD5E8E2), Color(0xFFA9CFC3)],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF2D5754),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4ECEA)),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _PlannerWeekdayLabel extends StatelessWidget {
  const _PlannerWeekdayLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF97A6A8),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.45,
        ),
      ),
    );
  }
}

class _SaveOutfitSheet extends StatefulWidget {
  const _SaveOutfitSheet({
    required this.pieces,
    required this.initialName,
    required this.initialTags,
    required this.tagSuggestions,
    required this.normalizeTags,
  });

  final List<ClosetItemPreview> pieces;
  final String initialName;
  final List<String> initialTags;
  final List<String> tagSuggestions;
  final List<String> Function(Iterable<String>) normalizeTags;

  @override
  State<_SaveOutfitSheet> createState() => _SaveOutfitSheetState();
}

class _SaveOutfitSheetState extends State<_SaveOutfitSheet> {
  late final TextEditingController _controller;
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _selectedTags = List<String>.from(widget.initialTags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags = _selectedTags.where((item) => item != tag).toList();
      } else {
        _selectedTags = widget.normalizeTags([..._selectedTags, tag]);
      }
    });
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _SavedOutfitDraft(
        name: name,
        tags: widget.normalizeTags(_selectedTags),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final availableHeight = math.max(
      0.0,
      media.size.height - keyboardInset - media.padding.top - 28,
    );
    final maxHeight = math.min(media.size.height * 0.82, availableHeight);
    final previewItems = widget.pieces.take(4).toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          keyboardInset > 0 ? 20 : 60,
          14,
          keyboardInset + 14,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(18),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8E5E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Save Outfit',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF203032),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add a name and a few tags so you can find this look faster later.',
                  style: TextStyle(
                    color: Color(0xFF708082),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Look name',
                    filled: true,
                    fillColor: const Color(0xFFF3F8F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 82,
                  child: Row(
                    children: previewItems.map((item) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: item == previewItems.last ? 0 : 8,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFEAF2F0),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tags',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF203032),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.tagSuggestions.map((tag) {
                    final selected = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) => _toggleTag(tag),
                      backgroundColor: const Color(0xFFF2F8F7),
                      selectedColor: const Color(0xFFDFF4EF),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF0A7A76)
                            : const Color(0xFFDCE7E4),
                      ),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFF0A7A76)
                            : const Color(0xFF6B7B7D),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0A7A76),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('Save Look'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannerDaySheet extends StatefulWidget {
  const _PlannerDaySheet({
    required this.date,
    required this.isPastDate,
    required this.initialEvent,
    required this.savedOutfits,
    required this.resolveOutfit,
    required this.resolveItems,
    required this.formatReadableDate,
  });

  final DateTime date;
  final bool isPastDate;
  final _PlannedEvent? initialEvent;
  final List<_SavedOutfit> savedOutfits;
  final _SavedOutfit? Function(String id) resolveOutfit;
  final List<ClosetItemPreview> Function(_SavedOutfit outfit) resolveItems;
  final String Function(DateTime date) formatReadableDate;

  @override
  State<_PlannerDaySheet> createState() => _PlannerDaySheetState();
}

class _PlannerDaySheetState extends State<_PlannerDaySheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  String? _selectedOutfitId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialEvent?.eventTitle ?? '',
    );
    _notesController = TextEditingController(
      text: widget.initialEvent?.eventNotes ?? '',
    );
    _selectedOutfitId = widget.initialEvent?.outfitId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final availableHeight = math.max(
      0.0,
      media.size.height - keyboardInset - media.padding.top - 28,
    );
    final maxHeight = math.min(
      media.size.height * 0.82,
      availableHeight,
    );
    final selectedOutfit =
        _selectedOutfitId == null ? null : widget.resolveOutfit(_selectedOutfitId!);
    final selectedItems =
        selectedOutfit == null ? const <ClosetItemPreview>[] : widget.resolveItems(selectedOutfit);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          keyboardInset > 0 ? 20 : 80,
          14,
          keyboardInset + 14,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
            ),
            child: ListView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(18),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8E5E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.formatReadableDate(widget.date),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF203032),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  enabled: !widget.isPastDate,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Event title',
                    hintText: 'Dinner, meeting, party...',
                    filled: true,
                    fillColor: const Color(0xFFF3F8F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  enabled: !widget.isPastDate,
                  onChanged: (_) => setState(() {}),
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Event details',
                    hintText: 'Location, dress code, notes...',
                    filled: true,
                    fillColor: const Color(0xFFF3F8F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Outfit Preview',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF233234),
                  ),
                ),
                const SizedBox(height: 10),
                if (selectedOutfit == null)
                  Text(
                    'Choose a saved look below to plan this date.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF708082),
                    ),
                  )
                else
                  _PlannerPreviewCard(
                    outfit: selectedOutfit,
                    items: selectedItems,
                    notes: _notesController.text.trim(),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.isPastDate || widget.initialEvent == null
                            ? null
                            : () {
                                FocusScope.of(context).unfocus();
                                Navigator.of(context).pop(
                                  const _PlannerDaySheetResult(removeEvent: true),
                                );
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD45F5D),
                          side: const BorderSide(
                            color: Color(0xFFF0CDCB),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Remove'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: widget.isPastDate || selectedOutfit == null
                            ? null
                            : () {
                                FocusScope.of(context).unfocus();
                                Navigator.of(context).pop(
                                  _PlannerDaySheetResult(
                                    outfitId: selectedOutfit.createdAt,
                                    eventTitle: _titleController.text,
                                    eventNotes: _notesController.text,
                                  ),
                                );
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0A7A76),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Save Event'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Choose a saved look',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF233234),
                  ),
                ),
                const SizedBox(height: 10),
                if (widget.isPastDate)
                  Text(
                    'Past dates are view-only. You can plan outfits starting from today.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF708082),
                      height: 1.45,
                    ),
                  )
                else if (widget.savedOutfits.isEmpty)
                  Text(
                    'Save an outfit first to schedule it on the calendar.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF708082),
                    ),
                  )
                else
                  ...List.generate(widget.savedOutfits.length, (index) {
                    final outfit = widget.savedOutfits[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == widget.savedOutfits.length - 1 ? 0 : 10,
                      ),
                      child: _PlannerLookTile(
                        outfit: outfit,
                        selected: _selectedOutfitId == outfit.createdAt,
                        onTap: () {
                          setState(() {
                            _selectedOutfitId = outfit.createdAt;
                          });
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannerDayCard extends StatelessWidget {
  const _PlannerDayCard({
    required this.date,
    required this.currentMonth,
    required this.eventTitle,
    required this.plannedOutfitName,
    required this.isEditable,
    required this.onTap,
  });

  final DateTime date;
  final DateTime currentMonth;
  final String? eventTitle;
  final String? plannedOutfitName;
  final bool isEditable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth = date.month == currentMonth.month;
    final today = DateTime.now();
    final isToday =
        date.year == today.year && date.month == today.month && date.day == today.day;
    final isPastDate = !isEditable;
    final hasPlan = plannedOutfitName != null;
    final label = (eventTitle?.trim().isNotEmpty ?? false)
        ? eventTitle!.trim()
        : plannedOutfitName;
    final canOpen = isEditable || hasPlan;

    return InkWell(
      onTap: canOpen ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: isToday
              ? const Color(0xFF0A7A76)
              : hasPlan
                  ? const Color(0xFFDFF4EF)
                  : isPastDate
                      ? const Color(0xFFF4F7F6)
                      : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday
                ? const Color(0xFF0A7A76)
                : canOpen
                    ? const Color(0xFFE1EAE7)
                    : const Color(0xFFF0F4F3),
            width: isToday ? 2.2 : 1,
          ),
          boxShadow: isToday
              ? const [
                  BoxShadow(
                    color: Color(0x330A7A76),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight <= 42;
            final tight = constraints.maxHeight <= 38;
            final padding = tight ? 3.0 : (compact ? 4.0 : 5.0);
            final dateBadgeSize = isToday
                ? (tight ? 18.0 : (compact ? 20.0 : 22.0))
                : null;
            final dateFontSize = isToday
                ? (tight ? 9.0 : 10.0)
                : (tight ? 8.0 : 9.5);
            final gap = tight ? 1.5 : 3.0;
            final markerIconSize = tight ? 10.0 : 12.0;
            final tagVertical = tight ? 1.5 : 2.0;
            final tagHorizontal = tight ? 3.0 : 4.0;

            return Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      width: dateBadgeSize,
                      height: dateBadgeSize,
                      alignment: Alignment.center,
                      padding: isToday
                          ? EdgeInsets.zero
                          : const EdgeInsets.symmetric(horizontal: 1),
                      decoration: isToday
                          ? const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isToday
                              ? const Color(0xFF0A7A76)
                              : isPastDate
                                  ? const Color(0xFFA9B7B8)
                                  : isCurrentMonth
                                      ? const Color(0xFF223234)
                                      : const Color(0xFFA6B3B4),
                          fontSize: dateFontSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  if (hasPlan)
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: tight ? 3 : 4,
                          vertical: tight ? 2 : 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A7A76),
                          borderRadius: BorderRadius.circular(tight ? 5 : 7),
                        ),
                        child: Text(
                          label ?? plannedOutfitName!,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: tight ? 6.5 : 7.0,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: isToday
                            ? Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: tagHorizontal,
                                  vertical: tagVertical,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Text(
                                  'TODAY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: tight ? 6.0 : 7.0,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: tight ? 0.2 : 0.4,
                                  ),
                                ),
                              )
                            : Icon(
                                canOpen ? Icons.add_rounded : Icons.remove_rounded,
                                size: markerIconSize,
                                color: isPastDate
                                    ? const Color(0xFFC4CFD0)
                                    : const Color(0xFFA9B7B8),
                              ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlannerDaySheetResult {
  const _PlannerDaySheetResult({
    this.outfitId,
    this.eventTitle = '',
    this.eventNotes = '',
    this.removeEvent = false,
  });

  final String? outfitId;
  final String eventTitle;
  final String eventNotes;
  final bool removeEvent;
}

class _PlannerPreviewCard extends StatelessWidget {
  const _PlannerPreviewCard({
    required this.outfit,
    required this.items,
    required this.notes,
  });

  final _SavedOutfit outfit;
  final List<ClosetItemPreview> items;
  final String notes;

  @override
  Widget build(BuildContext context) {
    final previewItems = items.take(2).toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1EAE7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 76,
              child: Row(
                children: previewItems.map((item) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: item == previewItems.last ? 0 : 6,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFFEAF2F0),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outfit.name,
                    style: const TextStyle(
                      color: Color(0xFF223234),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${items.length} pieces',
                    style: const TextStyle(
                      color: Color(0xFF8A999C),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                  if (notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      notes.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6E8082),
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannerLookTile extends StatelessWidget {
  const _PlannerLookTile({
    required this.outfit,
    required this.selected,
    required this.onTap,
  });

  final _SavedOutfit outfit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDFF4EF) : const Color(0xFFF4F8F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF0A7A76) : const Color(0xFFE2EBE8),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.calendar_today_rounded,
              color: selected ? const Color(0xFF0A7A76) : const Color(0xFF8FA1A3),
              size: 18,
            ),
            const SizedBox(width: 10),
              Expanded(
                child: Text(
                  outfit.tags.isEmpty
                      ? outfit.name
                      : '${outfit.name} • ${outfit.tags.first}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF233234),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (outfit.isFavorite)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFD05D79),
                  size: 16,
                ),
              ),
            ],
          ),
      ),
    );
  }
}

class _ClosetSelectionCard extends StatelessWidget {
  const _ClosetSelectionCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ClosetItemPreview item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF0A7A76) : const Color(0xFFE1EAE7),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFEAF2F0), Color(0xFFD6E4E0)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.checkroom_outlined,
                                color: Color(0xFF7C8D90),
                              ),
                            ),
                          );
                        },
                      ),
                      if (selected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0A7A76),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF233234),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8C9B9E),
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyClosetPrompt extends StatelessWidget {
  const _EmptyClosetPrompt();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF8EA0A2),
              size: 30,
            ),
            SizedBox(height: 10),
            Text(
              'No closet pieces yet. Add a few items to start building outfits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7B8C8F),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentLookChip extends StatelessWidget {
  const _CurrentLookChip({
    required this.item,
    required this.onRemove,
  });

  final ClosetItemPreview item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 146,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E9E6)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              item.imageUrl,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFFEAF2F0)),
                  child: SizedBox(width: 42, height: 42),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF233234),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8EA0A2),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFF93A0A3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentLookBundle {
  const _RecentLookBundle({
    required this.entry,
    required this.items,
  });

  final RecentOutfitHistoryEntry entry;
  final List<ClosetItemPreview> items;
}

class _RecentLookCard extends StatelessWidget {
  const _RecentLookCard({
    required this.bundle,
    required this.onTap,
  });

  final _RecentLookBundle bundle;
  final VoidCallback onTap;

  String _relativeLabel() {
    final createdAt = DateTime.tryParse(bundle.entry.createdAt);
    if (createdAt == null) return 'Recently added';
    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    return '${difference.inDays}d ago';
  }

  String _sourceLabel() {
    switch (bundle.entry.source.trim().toLowerCase()) {
      case 'planned':
        return 'Planned';
      case 'ai':
        return 'AI pick';
      case 'home':
      default:
        return 'From Home';
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = bundle.items.take(2).toList();
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 176,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6FAF9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE1ECE9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 76,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _RecentLookPreviewImage(
                      item: preview.isNotEmpty ? preview[0] : null,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 0,
                    child: _RecentLookPreviewImage(
                      item: preview.length > 1 ? preview[1] : null,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              bundle.entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: const Color(0xFF203032),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_sourceLabel()} • ${_relativeLabel()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF6F8082),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentLookPreviewImage extends StatelessWidget {
  const _RecentLookPreviewImage({
    required this.item,
    this.compact = false,
  });

  final ClosetItemPreview? item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 62 : 96,
      height: compact ? 62 : 76,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: item == null
            ? const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF3F6F5), Color(0xFFE0E9E7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              )
            : Image.network(
                item!.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF3F6F5), Color(0xFFE0E9E7)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _SavedLookCard extends StatelessWidget {
  const _SavedLookCard({
    required this.outfit,
    required this.items,
    required this.onTap,
  });

  final _SavedOutfit outfit;
  final List<ClosetItemPreview> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = items.take(2).toList();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: outfit.isFavorite ? const Color(0xFFFFFBF7) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: outfit.isFavorite
                ? const Color(0xFFF1D9B4)
                : const Color(0xFFE1EAE7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: preview.map((item) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: item == preview.last ? 0 : 6,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFEAF2F0),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (outfit.isFavorite)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFD05D79),
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              outfit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF223234),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            if (outfit.tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                outfit.tags.take(2).join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0A7A76),
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ] else
              const SizedBox(height: 4),
            const SizedBox(height: 2),
            Text(
              '${items.length} pieces',
              style: const TextStyle(
                color: Color(0xFF8A999C),
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedLookDetailCard extends StatelessWidget {
  const _SavedLookDetailCard({required this.item});

  final ClosetItemPreview item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFFEAF2F0)),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF223234),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${item.category.toUpperCase()} • ${item.subtitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8A999C),
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedOutfit {
  const _SavedOutfit({
    required this.name,
    required this.itemIds,
    required this.tags,
    required this.isFavorite,
    required this.createdAt,
  });

  final String name;
  final List<String> itemIds;
  final List<String> tags;
  final bool isFavorite;
  final String createdAt;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'item_ids': itemIds,
      'tags': tags,
      'is_favorite': isFavorite,
      'created_at': createdAt,
    };
  }

  factory _SavedOutfit.fromJson(Map<String, dynamic> json) {
    return _SavedOutfit(
      name: json['name'] as String? ?? 'Saved Look',
      itemIds: ((json['item_ids'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      tags: ((json['tags'] as List<dynamic>?) ?? const [])
          .map((tag) => tag.toString())
          .where((tag) => tag.trim().isNotEmpty)
          .toList(),
      isFavorite: json['is_favorite'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  _SavedOutfit copyWith({
    String? name,
    List<String>? itemIds,
    List<String>? tags,
    bool? isFavorite,
    String? createdAt,
  }) {
    return _SavedOutfit(
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class _SavedOutfitDraft {
  const _SavedOutfitDraft({
    required this.name,
    required this.tags,
  });

  final String name;
  final List<String> tags;
}

class _PlannedEvent {
  const _PlannedEvent({
    required this.outfitId,
    this.eventTitle = '',
    this.eventNotes = '',
  });

  final String outfitId;
  final String eventTitle;
  final String eventNotes;

  Map<String, dynamic> toJson() {
    return {
      'outfit_id': outfitId,
      'event_title': eventTitle,
      'event_notes': eventNotes,
    };
  }

  factory _PlannedEvent.fromJson(Map<String, dynamic> json) {
    return _PlannedEvent(
      outfitId: json['outfit_id'] as String? ?? '',
      eventTitle: json['event_title'] as String? ?? '',
      eventNotes: json['event_notes'] as String? ?? '',
    );
  }
}
