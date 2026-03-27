import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final ImagePicker _picker = ImagePicker();
  final ClosetAnalysisService _analysisService = ClosetAnalysisService();
  final ClosetService _closetService = ClosetService();
  var _isLaunchingCamera = false;
  var _selectedFilter = 'All Items';
  var _isLoadingCloset = true;
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
    _loadClosetCount();
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

  Future<void> _showRenameItemSheet(ClosetItemPreview item) async {
    final controller = TextEditingController(text: item.title);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            top: 80,
            bottom: MediaQuery.of(context).viewInsets.bottom + 14,
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
                  const Text(
                    'Rename Piece',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF203032),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.words,
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
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final newName = controller.text.trim();
                        if (newName.isEmpty) return;

                        await _closetService.renameClosetItem(
                          itemId: item.id,
                          newName: newName,
                        );

                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        await _loadClosetCount();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Piece renamed.')),
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
                      child: const Text('Save Name'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    controller.dispose();
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
                      _FeaturedClosetCard(
                        item: filteredItems.first,
                        onTap: () => _showRenameItemSheet(filteredItems.first),
                      ),
                      const SizedBox(height: 14),
                      GridView.builder(
                        itemCount: filteredItems.length - 1,
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
                          final item = filteredItems[index + 1];
                          return _ClosetGridCard(
                            item: item,
                            onTap: () => _showRenameItemSheet(item),
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
                              'Build a Minimalist Capsule',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF203032),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "You have 12 items that match the 'Quiet Luxury' aesthetic. Want us to generate 5 outfits for your upcoming trip?",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF3F6A73),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () {},
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
                              child: const Text('Generate Lookbook'),
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

class _FeaturedClosetCard extends StatelessWidget {
  const _FeaturedClosetCard({required this.item, required this.onTap});

  final ClosetItemPreview item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F7F4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 332,
              width: double.infinity,
              child: _ClosetImage(
                imageUrl: item.imageUrl,
                borderRadius: 16,
                tall: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF203032),
                    ),
                  ),
                ),
                const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF0A7A76),
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 6),
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
