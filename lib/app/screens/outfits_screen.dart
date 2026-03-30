import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/closet_item_preview.dart';
import '../services/closet_service.dart';
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

  final ClosetService _closetService = ClosetService();
  List<ClosetItemPreview> _closetItems = const [];
  List<_SavedOutfit> _savedOutfits = const [];
  ClosetItemPreview? _selectedTop;
  ClosetItemPreview? _selectedBottom;
  ClosetItemPreview? _selectedShoe;
  ClosetItemPreview? _selectedLayer;
  var _selectedFilter = 'All Items';
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
    setState(() => _savedOutfits = parsed);
  }

  Future<void> _persistSavedOutfits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _savedOutfitsKey,
      _savedOutfits.map((outfit) => jsonEncode(outfit.toJson())).toList(),
    );
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

    setState(() => _isSaving = true);

    try {
      final outfit = _SavedOutfit(
        name: 'Look ${_savedOutfits.length + 1}',
        itemIds: pieces.map((item) => item.id).toList(),
        createdAt: DateTime.now().toIso8601String(),
      );
      setState(() {
        _savedOutfits = [outfit, ..._savedOutfits];
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

  Future<void> _renameSavedOutfit(_SavedOutfit outfit, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _savedOutfits = _savedOutfits
          .map((saved) => saved.createdAt == outfit.createdAt
              ? saved.copyWith(name: trimmed)
              : saved)
          .toList();
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
    final titleController = TextEditingController(
      text: plannedEvent?.eventTitle ?? '',
    );
    final notesController = TextEditingController(
      text: plannedEvent?.eventNotes ?? '',
    );
    String? selectedOutfitId = plannedEvent?.outfitId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedOutfit =
                selectedOutfitId == null ? null : _savedOutfitById(selectedOutfitId!);
            final selectedItems =
                selectedOutfit == null ? const <ClosetItemPreview>[] : _resolveSavedOutfitItems(selectedOutfit);

            return Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                80,
                14,
                MediaQuery.of(context).viewInsets.bottom + 14,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.82,
                  ),
                  child: Padding(
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
                          _formatReadableDate(date),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF203032),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: titleController,
                          enabled: !isPastDate,
                          onChanged: (_) => setModalState(() {}),
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
                          controller: notesController,
                          enabled: !isPastDate,
                          onChanged: (_) => setModalState(() {}),
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
                            notes: notesController.text.trim(),
                          ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isPastDate || plannedEvent == null
                                    ? null
                                    : () async {
                                        Navigator.of(context).pop();
                                        await _removePlannedOutfit(date);
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
                                onPressed: isPastDate || selectedOutfit == null
                                    ? null
                                    : () async {
                                        FocusScope.of(context).unfocus();
                                        Navigator.of(context).pop();
                                        await _scheduleOutfitForDate(
                                          outfit: selectedOutfit,
                                          date: date,
                                          eventTitle: titleController.text,
                                          eventNotes: notesController.text,
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
                        if (isPastDate)
                          Text(
                            'Past dates are view-only. You can plan outfits starting from today.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF708082),
                              height: 1.45,
                            ),
                          )
                        else if (_savedOutfits.isEmpty)
                          Text(
                            'Save an outfit first to schedule it on the calendar.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF708082),
                            ),
                          )
                        else
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _savedOutfits.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final outfit = _savedOutfits[index];
                                return _PlannerLookTile(
                                  outfit: outfit,
                                  selected: selectedOutfitId == outfit.createdAt,
                                  onTap: () {
                                    setModalState(() {
                                      selectedOutfitId = outfit.createdAt;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    notesController.dispose();
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 14,
            top: 60,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
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
                    'Saved Look Details',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF203032),
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
                            Navigator.of(context).pop();
                            await _renameSavedOutfit(outfit, newName);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0A7A76),
                            side: const BorderSide(color: Color(0xFFCFE4DE)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: const Text('Rename'),
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
        );
      },
    );
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
                    const SizedBox(height: 16),
                    _MoodboardPanel(
                      top: _selectedTop,
                      bottom: _selectedBottom,
                      shoe: _selectedShoe,
                      layer: _selectedLayer,
                    ),
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
                            SizedBox(
                              height: 116,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _savedOutfits.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final saved = _savedOutfits[index];
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
                                icon: const Icon(Icons.chevron_left_rounded),
                                color: const Color(0xFF6E8082),
                              ),
                              Text(
                                '${_monthLabel(_plannerMonth)} ${_plannerMonth.year}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF233234),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _plannerMonth = DateTime(
                                      _plannerMonth.year,
                                      _plannerMonth.month + 1,
                                    );
                                  });
                                },
                                icon: const Icon(Icons.chevron_right_rounded),
                                color: const Color(0xFF6E8082),
                              ),
                            ],
                          ),
                            const SizedBox(height: 6),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final crossAxisSpacing =
                                    constraints.maxWidth < 360 ? 6.0 : 8.0;
                                final cellWidth =
                                    (constraints.maxWidth - (crossAxisSpacing * 6)) / 7;
                                final cellHeight = math.max(
                                  44.0,
                                  math.min(58.0, cellWidth * 0.96),
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
                                    const SizedBox(height: 8),
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
  const _SoftPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4ECEA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
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
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: isToday
              ? const Color(0xFF0A7A76)
              : hasPlan
                  ? const Color(0xFFDFF4EF)
                  : isPastDate
                      ? const Color(0xFFF4F7F6)
                      : Colors.white,
          borderRadius: BorderRadius.circular(14),
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
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    width: isToday ? 26 : null,
                    height: isToday ? 26 : null,
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
                        fontSize: isToday ? 12 : 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              if (hasPlan)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A7A76),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label ?? plannedOutfitName!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: const Text(
                              'TODAY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          )
                        : Icon(
                            canOpen ? Icons.add_rounded : Icons.remove_rounded,
                            size: 14,
                            color: isPastDate
                                ? const Color(0xFFC4CFD0)
                                : const Color(0xFFA9B7B8),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
                outfit.name,
                style: const TextStyle(
                  color: Color(0xFF233234),
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

class _MoodboardPanel extends StatelessWidget {
  const _MoodboardPanel({
    required this.top,
    required this.bottom,
    required this.shoe,
    required this.layer,
  });

  final ClosetItemPreview? top;
  final ClosetItemPreview? bottom;
  final ClosetItemPreview? shoe;
  final ClosetItemPreview? layer;

  @override
  Widget build(BuildContext context) {
    final pieces = [top, bottom, shoe, layer].whereType<ClosetItemPreview>().toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF7F5), Color(0xFFF8FBFA)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0EBE8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 240,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 12,
                    left: 10,
                    right: 50,
                    child: _PhotoPolaroid(item: pieces.isNotEmpty ? pieces[0] : null),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 0,
                    width: 120,
                    child: _PhotoPolaroid(
                      item: pieces.length > 1 ? pieces[1] : null,
                      tilt: -0.12,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _MiniActionIcon(icon: Icons.search_rounded),
                SizedBox(width: 12),
                _MiniActionIcon(icon: Icons.auto_awesome_rounded),
                SizedBox(width: 12),
                _MiniActionIcon(icon: Icons.undo_rounded),
                SizedBox(width: 12),
                _MiniActionIcon(icon: Icons.refresh_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPolaroid extends StatelessWidget {
  const _PhotoPolaroid({
    required this.item,
    this.tilt = 0.06,
    this.compact = false,
  });

  final ClosetItemPreview? item;
  final double tilt;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Container(
        height: compact ? 136 : 172,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
}

class _MiniActionIcon extends StatelessWidget {
  const _MiniActionIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: const Color(0xFF6A7E80), size: 18),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE1EAE7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
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
            ),
            const SizedBox(height: 8),
            Text(
              outfit.name,
              style: const TextStyle(
                color: Color(0xFF223234),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
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
    required this.createdAt,
  });

  final String name;
  final List<String> itemIds;
  final String createdAt;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'item_ids': itemIds,
      'created_at': createdAt,
    };
  }

  factory _SavedOutfit.fromJson(Map<String, dynamic> json) {
    return _SavedOutfit(
      name: json['name'] as String? ?? 'Saved Look',
      itemIds: ((json['item_ids'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  _SavedOutfit copyWith({
    String? name,
    List<String>? itemIds,
    String? createdAt,
  }) {
    return _SavedOutfit(
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
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
