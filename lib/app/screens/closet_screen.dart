import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/closet_item_preview.dart';
import '../services/closet_analysis_service.dart';
import '../services/closet_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/onboarding_shell.dart';
import 'add_closet_item_screen.dart';
import 'home_screen.dart';
import 'outfits_screen.dart';
import 'settings_screen.dart';

class ClosetScreen extends StatefulWidget {
  const ClosetScreen({super.key});

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  static const _savedOutfitsKeyPrefix = 'stylex_saved_outfits_v2';
  static const _plannedOutfitsKeyPrefix = 'stylex_planned_outfits_v1';
  static const _typeOptions = ['Top', 'Bottom', 'Shoe', 'Outerwear'];

  final ImagePicker _picker = ImagePicker();
  final ClosetAnalysisService _analysisService = ClosetAnalysisService();
  final ClosetService _closetService = ClosetService();
  var _isLaunchingCamera = false;
  var _isGeneratingLookbook = false;
  var _selectedFilter = 'All Items';
  var _isLoadingCloset = true;
  var _primaryStyleSlug = 'minimalist';
  List<ClosetItemPreview> _items = const [];

  static const _filters = [
    'All Items',
    'Outerwear',
    'Tops',
    'Bottoms',
    'Shoes',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCloset();
  }

  Future<void> _initializeCloset() async {
    await Future.wait([
      _loadClosetCount(),
      _loadStylePreference(),
    ]);
  }

  Future<void> _loadClosetCount() async {
    try {
      final items = await _closetService.fetchClosetItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoadingCloset = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _isLoadingCloset = false;
      });
    }
  }

  Future<void> _loadStylePreference() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('primary_style_slug')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      final slug = (response?['primary_style_slug'] as String?)?.trim();
      if (slug == null || slug.isEmpty) return;
      setState(() => _primaryStyleSlug = slug);
    } catch (_) {
      // Keep the closet usable even if the style profile table is unavailable.
    }
  }

  Future<void> _generateStyleLookbook() async {
    if (_isGeneratingLookbook) return;

    final suggestions = _closetService.buildStyleLookbookSuggestions(
      items: _items,
      styleSlug: _primaryStyleSlug,
      count: 5,
      includeOuterwear: true,
    );

    if (suggestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one top, bottom, and shoe so Style AI can build a lookbook.',
          ),
        ),
      );
      return;
    }

    setState(() => _isGeneratingLookbook = true);
    try {
      final lookbook = List<_GeneratedLookbookEntry>.generate(
        suggestions.length,
        (index) => _GeneratedLookbookEntry(
          name: _lookbookNameForIndex(index),
          items: suggestions[index],
        ),
      );

      await _showGeneratedLookbookSheet(lookbook);
    } finally {
      if (mounted) {
        setState(() => _isGeneratingLookbook = false);
      }
    }
  }

  Future<void> _showGeneratedLookbookSheet(
    List<_GeneratedLookbookEntry> lookbook,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 56, 14, 14),
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
                      '$_styleDisplayName Lookbook',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF203032),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Style AI built ${lookbook.length} outfit ideas from your current closet. Save them to your atelier or open the outfit maker to tweak them.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6A7C7E),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.38,
                      child: ListView.separated(
                        itemCount: lookbook.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _LookbookSuggestionCard(entry: lookbook[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(this.context);
                          final addedCount = await _saveGeneratedLookbook(lookbook);
                          if (!mounted) return;
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                addedCount == 0
                                    ? 'These looks are already saved in your atelier.'
                                    : 'Saved $addedCount looks to your atelier.',
                              ),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0A7A76),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        icon: const Icon(Icons.bookmark_added_rounded, size: 18),
                        label: const Text('Save Lookbook To Outfits'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(this.context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => const OutfitsScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF203032),
                          side: const BorderSide(color: Color(0xFFD6E5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Open Outfit Atelier'),
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
  }

  Future<int> _saveGeneratedLookbook(
    List<_GeneratedLookbookEntry> lookbook,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    final storageKey = '$_savedOutfitsKeyPrefix:$currentUserId';
    final existingEntries = prefs.getStringList(storageKey) ?? const [];
    final signatures = <String>{};

    for (final entry in existingEntries) {
      try {
        final json = jsonDecode(entry) as Map<String, dynamic>;
        final ids = (json['item_ids'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
        signatures.add(ids.join('|'));
      } catch (_) {
        continue;
      }
    }

    final newEntries = <String>[];
    var addedCount = 0;
    for (var index = 0; index < lookbook.length; index++) {
      final look = lookbook[index];
      final itemIds = look.items.map((item) => item.id).toList();
      final signature = itemIds.join('|');
      if (!signatures.add(signature)) continue;

      newEntries.add(
        jsonEncode({
          'name': look.name,
          'item_ids': itemIds,
          'tags': [_styleDisplayName],
          'created_at': DateTime.now()
              .add(Duration(milliseconds: index))
              .toIso8601String(),
        }),
      );
      addedCount++;
    }

    if (addedCount == 0) return 0;

    await prefs.setStringList(
      storageKey,
      [
        ...newEntries,
        ...existingEntries,
      ],
    );
    HomeScreen.clearSessionCache();

    return addedCount;
  }

  String get _styleDisplayName {
    switch (_primaryStyleSlug) {
      case 'streetwear':
        return 'Streetwear';
      case 'formal':
        return 'Formal';
      case 'bohemian':
        return 'Bohemian';
      case 'classic-vintage':
        return 'Classic Vintage';
      case 'minimalist':
      default:
        return 'Minimalist';
    }
  }

  String get _styleLookbookTitle {
    switch (_primaryStyleSlug) {
      case 'streetwear':
        return 'Build a Streetwear Rotation';
      case 'formal':
        return 'Build a Formal Edit';
      case 'bohemian':
        return 'Build a Bohemian Story';
      case 'classic-vintage':
        return 'Build a Heritage Capsule';
      case 'minimalist':
      default:
        return 'Build a Minimalist Capsule';
    }
  }

  String get _styleLookbookDescription {
    final itemCount = _items.length;
    switch (_primaryStyleSlug) {
      case 'streetwear':
        return 'You have $itemCount pieces ready for a bold, layered streetwear mix. Want us to generate 5 fresh outfits from your closet?';
      case 'formal':
        return 'You have $itemCount pieces that can be styled into a polished formal rotation. Want us to generate 5 refined outfit ideas?';
      case 'bohemian':
        return 'You have $itemCount pieces that can lean into a softer, textured bohemian mood. Want us to generate 5 outfits for you?';
      case 'classic-vintage':
        return 'You have $itemCount pieces that fit a timeless classic-vintage direction. Want us to generate 5 heritage-inspired outfits?';
      case 'minimalist':
      default:
        return 'You have $itemCount closet pieces ready for a clean, quiet-luxury edit. Want us to generate 5 outfits for you?';
    }
  }

  String _lookbookNameForIndex(int index) {
    const minimalistNames = [
      'Quiet Layers',
      'Clean Contrast',
      'Soft Neutrals',
      'Refined Everyday',
      'City Minimal',
    ];
    const streetwearNames = [
      'Concrete Layers',
      'Off-Duty Edge',
      'Weekend Motion',
      'Night Shift',
      'Clean Hype',
    ];
    const formalNames = [
      'Tailored Balance',
      'Polished Meeting',
      'Evening Sharp',
      'Boardroom Calm',
      'Formal Reset',
    ];
    const bohemianNames = [
      'Sunlit Texture',
      'Free Spirit',
      'Earthy Layers',
      'Artful Ease',
      'Soft Wander',
    ];
    const vintageNames = [
      'Heritage Edit',
      'Retro Tailored',
      'Archive Favorite',
      'Timeless Layers',
      'Old-Money Ease',
    ];

    final names = switch (_primaryStyleSlug) {
      'streetwear' => streetwearNames,
      'formal' => formalNames,
      'bohemian' => bohemianNames,
      'classic-vintage' => vintageNames,
      _ => minimalistNames,
    };

    if (index < names.length) return names[index];
    return '$_styleDisplayName Look ${index + 1}';
  }

  Future<void> _showAddOptions() async {
    if (_isLaunchingCamera) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add To Closet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF203032),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose how you want to add your clothing item.',
                      style: TextStyle(
                        color: Color(0xFF6A7C7E),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SourceOptionTile(
                      icon: Icons.photo_camera_outlined,
                      title: 'Use Camera',
                      subtitle: 'Capture a piece right now',
                      onTap: () {
                        Navigator.of(context).pop();
                        _pickImage(
                          source: ImageSource.camera,
                          label: 'CAPTURE',
                          sourceValue: 'camera_upload',
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _SourceOptionTile(
                      icon: Icons.photo_library_outlined,
                      title: 'Upload Photo',
                      subtitle: 'Choose an existing image',
                      onTap: () {
                        Navigator.of(context).pop();
                        _pickImage(
                          source: ImageSource.gallery,
                          label: 'UPLOAD',
                          sourceValue: 'gallery_upload',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditItemSheet(ClosetItemPreview item) async {
    final result = await showModalBottomSheet<_ClosetItemEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ClosetItemEditorSheet(
          item: item,
          initialType: _normalizedTypeFor(item.category),
          typeOptions: _typeOptions,
        );
      },
    );

    if (!mounted || result == null) return;

    try {
      if (result.deleteRequested) {
        final confirmed = await _confirmDeleteItem(item.title);
        if (!mounted || !confirmed) return;

        await _closetService.deleteClosetItem(itemId: item.id);
        await _removeDeletedItemFromSavedLooks(item.id);
        HomeScreen.clearSessionCache();
        if (!mounted) return;
        await _loadClosetCount();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Piece deleted.')),
        );
        return;
      }

      await _closetService.updateClosetItem(
        itemId: item.id,
        newName: result.name!,
        category: result.category!,
        primaryColor: result.primaryColor!,
        material: result.material!,
      );
      HomeScreen.clearSessionCache();
      if (!mounted) return;
      await _loadClosetCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Piece updated.')),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $error')),
      );
    }
  }

  String _normalizedTypeFor(String category) {
    final normalized = category.trim().toLowerCase();
    if (normalized == 'tops' || normalized == 'top') return 'Top';
    if (normalized == 'bottoms' || normalized == 'bottom') return 'Bottom';
    if (normalized == 'shoes' || normalized == 'shoe') return 'Shoe';
    if (normalized == 'outerwear') return 'Outerwear';
    return 'Top';
  }

  Future<bool> _confirmDeleteItem(String itemName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Piece?'),
          content: Text(
            'Remove $itemName from your closet? Saved looks that depend on it will be cleaned up too.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD45F5D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _removeDeletedItemFromSavedLooks(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    final savedLooksKey = '$_savedOutfitsKeyPrefix:$currentUserId';
    final plannedLooksKey = '$_plannedOutfitsKeyPrefix:$currentUserId';

    final rawSavedLooks = prefs.getStringList(savedLooksKey) ?? const [];
    final updatedSavedLooks = <String>[];
    final removedOutfitIds = <String>{};

    for (final entry in rawSavedLooks) {
      try {
        final json = jsonDecode(entry) as Map<String, dynamic>;
        final itemIds = ((json['item_ids'] as List<dynamic>?) ?? const [])
            .map((item) => item.toString())
            .toList();

        if (!itemIds.contains(itemId)) {
          updatedSavedLooks.add(entry);
          continue;
        }

        final nextItemIds = itemIds.where((id) => id != itemId).toList();
        if (nextItemIds.length < 2) {
          removedOutfitIds.add(json['created_at']?.toString() ?? '');
          continue;
        }

        json['item_ids'] = nextItemIds;
        updatedSavedLooks.add(jsonEncode(json));
      } catch (_) {
        updatedSavedLooks.add(entry);
      }
    }

    await prefs.setStringList(savedLooksKey, updatedSavedLooks);

    final rawPlannedLooks = prefs.getString(plannedLooksKey);
    if (rawPlannedLooks == null || rawPlannedLooks.isEmpty) return;

    try {
      final decoded = jsonDecode(rawPlannedLooks) as Map<String, dynamic>;
      final updatedPlanned = Map<String, dynamic>.fromEntries(
        decoded.entries.where((entry) {
          final value = entry.value;
          final plannedOutfitId = value is String
              ? value
              : ((value as Map<String, dynamic>)['outfit_id'] ??
                      value['outfitId'])
                  ?.toString();
          return plannedOutfitId == null ||
              !removedOutfitIds.contains(plannedOutfitId);
        }),
      );
      await prefs.setString(plannedLooksKey, jsonEncode(updatedPlanned));
    } catch (_) {
      // Leave planner data untouched if older local data cannot be parsed.
    }
  }

  Future<void> _pickImage({
    required ImageSource source,
    required String label,
    required String sourceValue,
  }) async {
    if (_isLaunchingCamera) return;

    var analysisDialogShown = false;
    setState(() => _isLaunchingCamera = true);

    try {
      final captured = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (!mounted || captured == null) return;

      _showAnalysisDialog();
      analysisDialogShown = true;
      final analysis = await _analysisService.analyzeImage(
        imagePath: captured.path,
        source: sourceValue,
      );
      if (!mounted) return;
      if (analysisDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        analysisDialogShown = false;
      }

      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => AddClosetItemScreen(
            imagePath: captured.path,
            sourceLabel: label,
            sourceValue: sourceValue,
            analysis: analysis,
          ),
        ),
      );

      if (saved == true) {
        HomeScreen.clearSessionCache();
        await _loadClosetCount();
      }
    } catch (_) {
      if (!mounted) return;
      if (analysisDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera could not be opened on this device right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLaunchingCamera = false);
      }
    }
  }

  void _showAnalysisDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Color(0xFF0A7A76),
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Analyzing your item...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF203032),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'We are generating AI tags like type, color, and material before the preview opens.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6A7C7E),
                      height: 1.45,
                    ),
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
    if (tab == AppTab.closet) return;

    if (tab == AppTab.home) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
        ),
      );
      return;
    }

    if (tab == AppTab.outfits) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const OutfitsScreen(),
        ),
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
    final filteredItems = _filteredItemsForSelection();
    final hasClosetItems = filteredItems.isNotEmpty;

    return Scaffold(
      body: AppViewport(
        child: AppPanel(
          padding: EdgeInsets.zero,
          borderRadius: 0,
          clip: true,
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 122),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFE8F5F2),
                            foregroundColor: const Color(0xFF0A7A76),
                          ),
                          icon: const Icon(Icons.menu_rounded),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'STYLEX',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2C4B4D),
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFE7C79F), Color(0xFFD9A77D)],
                            ),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'CURATION',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF6CA4A0),
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Digital\nCloset',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 0.95,
                        letterSpacing: -1.6,
                        color: const Color(0xFF203032),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final filter = _filters[index];
                          final selected = filter == _selectedFilter;
                          return ChoiceChip(
                            label: Text(filter),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _selectedFilter = filter);
                            },
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF7A8D8F),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            selectedColor: const Color(0xFF0A7A76),
                            backgroundColor: const Color(0xFFF0F6F5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: selected
                                    ? const Color(0xFF0A7A76)
                                    : const Color(0xFFE3EFEC),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemCount: _filters.length,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_isLoadingCloset)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF0A7A76),
                          ),
                        ),
                      )
                    else if (hasClosetItems) ...[
                      GridView.builder(
                        itemCount: filteredItems.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.76,
                        ),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _ClosetGridCard(
                            item: item,
                            onTap: () => _showEditItemSheet(item),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCAEDFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0A7A76),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(8)),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'STYLE AI SUGGESTION',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFF1D5F69),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _styleLookbookTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF203032),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _styleLookbookDescription,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF3F6A73),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed:
                                  _isGeneratingLookbook ? null : _generateStyleLookbook,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF203032),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: _isGeneratingLookbook
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Generate Lookbook'),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      _EmptyClosetState(onAddPressed: _showAddOptions),
                  ],
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: StylexBottomNav(
                  selectedTab: AppTab.closet,
                  showAddButton: true,
                  onAddPressed: _isLaunchingCamera ? null : _showAddOptions,
                  onTabSelected: _handleTabSelection,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<ClosetItemPreview> _filteredItemsForSelection() {
    if (_selectedFilter == 'All Items') {
      return _items;
    }

    return _items.where((item) {
      final normalizedCategory = item.category.trim().toLowerCase();
      final normalizedFilter = _selectedFilter.trim().toLowerCase();

      if (normalizedFilter == 'tops') {
        return normalizedCategory == 'top' || normalizedCategory == 'tops';
      }
      if (normalizedFilter == 'bottoms') {
        return normalizedCategory == 'bottom' || normalizedCategory == 'bottoms';
      }
      if (normalizedFilter == 'shoes') {
        return normalizedCategory == 'shoe' || normalizedCategory == 'shoes';
      }
      if (normalizedFilter == 'outerwear') {
        return normalizedCategory == 'outerwear';
      }

      return normalizedCategory == normalizedFilter;
    }).toList();
  }
}

class _EmptyClosetState extends StatelessWidget {
  const _EmptyClosetState({required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE1EEEB)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFDFF4EF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.checkroom_outlined,
              size: 34,
              color: Color(0xFF0A7A76),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Nothing to see here... add your first item.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF203032),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Once you capture a piece, your closet and style suggestions will start showing up here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6A7C7E),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAddPressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0A7A76),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: const Text('Add Your First Item'),
          ),
        ],
      ),
    );
  }
}

class _SourceOptionTile extends StatelessWidget {
  const _SourceOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F8F7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE1EEEB)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFDFF4EF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF0A7A76)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF203032),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6A7C7E),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF87A1A3),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosetGridCard extends StatelessWidget {
  const _ClosetGridCard({required this.item, required this.onTap});

  final ClosetItemPreview item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8F7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ClosetImage(
                imageUrl: item.imageUrl,
                borderRadius: 14,
                tall: false,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF203032),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: Color(0xFF0A7A76),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF91A2A4),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosetImage extends StatelessWidget {
  const _ClosetImage({
    required this.imageUrl,
    required this.borderRadius,
    this.tall = false,
  });

  final String imageUrl;
  final double borderRadius;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE9F3F1), Color(0xFFCFE2DE)],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Color(0xFF6A7C7E),
                    ),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE9F3F1), Color(0xFFCFE2DE)],
                    ),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF0A7A76),
                    ),
                  ),
                );
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: tall ? 0.08 : 0.18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LookbookSuggestionCard extends StatelessWidget {
  const _LookbookSuggestionCard({required this.entry});

  final _GeneratedLookbookEntry entry;

  @override
  Widget build(BuildContext context) {
    final previewItems = entry.items.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1ECE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF203032),
                ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: Row(
              children: previewItems.map((item) {
                final isLast = item == previewItems.last;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFFE3EEEA),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.checkroom_outlined,
                                color: Color(0xFF6A7C7E),
                              ),
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entry.items
                .map(
                  (item) => _LookbookPieceChip(
                    label: '${item.category.toUpperCase()} • ${item.title}',
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LookbookPieceChip extends StatelessWidget {
  const _LookbookPieceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0EAE6)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF506366),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GeneratedLookbookEntry {
  const _GeneratedLookbookEntry({
    required this.name,
    required this.items,
  });

  final String name;
  final List<ClosetItemPreview> items;
}

class _EditorLabel extends StatelessWidget {
  const _EditorLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF203032),
          ),
    );
  }
}

class _ClosetItemEditorSheet extends StatefulWidget {
  const _ClosetItemEditorSheet({
    required this.item,
    required this.initialType,
    required this.typeOptions,
  });

  final ClosetItemPreview item;
  final String initialType;
  final List<String> typeOptions;

  @override
  State<_ClosetItemEditorSheet> createState() => _ClosetItemEditorSheetState();
}

class _ClosetItemEditorSheetState extends State<_ClosetItemEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _colorController;
  late final TextEditingController _materialController;
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.title);
    _colorController = TextEditingController(text: widget.item.primaryColor);
    _materialController = TextEditingController(
      text: widget.item.material.trim().isEmpty ? 'Unknown' : widget.item.material,
    );
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    _materialController.dispose();
    super.dispose();
  }

  void _closeWithDelete() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(const _ClosetItemEditResult.delete());
  }

  void _closeWithSave() {
    final updatedName = _nameController.text.trim();
    final updatedColor = _colorController.text.trim();
    final updatedMaterial = _materialController.text.trim();
    if (updatedName.isEmpty || updatedColor.isEmpty || updatedMaterial.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _ClosetItemEditResult.save(
        name: updatedName,
        category: _selectedType,
        primaryColor: updatedColor,
        material: updatedMaterial,
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
    final maxHeight = math.min(
      media.size.height * 0.86,
      availableHeight,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          top: keyboardInset > 0 ? 20 : 64,
          bottom: keyboardInset + 14,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  const Text(
                    'Edit Piece',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF203032),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Update this item or remove it from your closet.',
                    style: TextStyle(
                      color: Color(0xFF6A7C7E),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F8F7),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: _ClosetImage(
                            imageUrl: widget.item.imageUrl,
                            borderRadius: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nameController.text.trim().isEmpty
                                    ? widget.item.title
                                    : _nameController.text.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF203032),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_selectedType.toUpperCase()} • ${_colorController.text.trim().toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF8B9C9F),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _EditorLabel(label: 'Piece Name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Classic Tee',
                      filled: true,
                      fillColor: const Color(0xFFF4F8F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _EditorLabel(label: 'Clothing Type'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.typeOptions.map((option) {
                      final selected = option == _selectedType;
                      return ChoiceChip(
                        label: Text(option),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() => _selectedType = option);
                        },
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF6F8082),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                        backgroundColor: const Color(0xFFF4F8F7),
                        selectedColor: const Color(0xFF0A7A76),
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF0A7A76)
                              : const Color(0xFFDCE7E4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _EditorLabel(label: 'Primary Color'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _colorController,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Blue',
                                filled: true,
                                fillColor: const Color(0xFFF4F8F7),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _EditorLabel(label: 'Material'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _materialController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: 'Cotton Blend',
                                filled: true,
                                fillColor: const Color(0xFFF4F8F7),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _closeWithDelete,
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
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                      ),
                      label: const Text('Delete Piece'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _closeWithSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0A7A76),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClosetItemEditResult {
  const _ClosetItemEditResult.save({
    required this.name,
    required this.category,
    required this.primaryColor,
    required this.material,
  }) : deleteRequested = false;

  const _ClosetItemEditResult.delete()
      : name = null,
        category = null,
        primaryColor = null,
        material = null,
        deleteRequested = true;

  final String? name;
  final String? category;
  final String? primaryColor;
  final String? material;
  final bool deleteRequested;
}
