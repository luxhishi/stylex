import 'dart:convert';

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
  static const _savedOutfitsKey = 'stylex_saved_outfits_v1';
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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadClosetItems(),
      _loadSavedOutfits(),
    ]);
  }

  Future<void> _loadClosetItems() async {
    try {
      final items = await _closetService.fetchClosetItems();
      if (!mounted) return;
      setState(() {
        _closetItems = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _closetItems = const [];
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
