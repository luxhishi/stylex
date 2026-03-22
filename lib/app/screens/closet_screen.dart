import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/app_bottom_nav.dart';
import '../widgets/onboarding_shell.dart';
import 'add_closet_item_screen.dart';
import 'home_screen.dart';

class ClosetScreen extends StatefulWidget {
  const ClosetScreen({super.key});

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  final ImagePicker _picker = ImagePicker();
  var _isLaunchingCamera = false;
  var _selectedFilter = 'All Items';

  static const _filters = [
    'All Items',
    'Tops',
    'Bottoms',
    'Shoes',
  ];

  static const _items = [
    _ClosetItem(
      title: 'Oversized Blazer',
      subtitle: 'BEIGE    PROFESSIONAL',
      palette: [Color(0xFFF6F2EA), Color(0xFFD6C6B1)],
      tall: true,
    ),
    _ClosetItem(
      title: 'Straight Denim',
      subtitle: 'BLUE',
      palette: [Color(0xFF4E6F95), Color(0xFF9BB8D8)],
    ),
    _ClosetItem(
      title: 'Studio Sneakers',
      subtitle: 'WHITE',
      palette: [Color(0xFFF8F8F4), Color(0xFFDBDED5)],
    ),
    _ClosetItem(
      title: 'Essential Tee',
      subtitle: 'BLACK',
      palette: [Color(0xFF0F171A), Color(0xFF373E42)],
    ),
    _ClosetItem(
      title: 'Heirloom Watch',
      subtitle: 'GOLD',
      palette: [Color(0xFF30251B), Color(0xFFD9BA60)],
    ),
    _ClosetItem(
      title: 'Merino Sweater',
      subtitle: 'BLACK',
      palette: [Color(0xFF1A1A1D), Color(0xFF44464D)],
    ),
    _ClosetItem(
      title: 'Floral Midi',
      subtitle: 'PINK',
      palette: [Color(0xFFD4B5BD), Color(0xFFF0E1E4)],
    ),
  ];

  Future<void> _openCamera() async {
    if (_isLaunchingCamera) return;

    setState(() => _isLaunchingCamera = true);

    try {
      final captured = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (!mounted || captured == null) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AddClosetItemScreen(imagePath: captured.path),
        ),
      );
    } catch (_) {
      if (!mounted) return;
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tab.name} is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                          onPressed: () {},
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
                    _FeaturedClosetCard(item: _items.first),
                    const SizedBox(height: 14),
                    GridView.builder(
                      itemCount: _items.length - 1,
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
                        final item = _items[index + 1];
                        return _ClosetGridCard(item: item);
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
                  onAddPressed: _isLaunchingCamera ? null : _openCamera,
                  onTabSelected: _handleTabSelection,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosetItem {
  const _ClosetItem({
    required this.title,
    required this.subtitle,
    required this.palette,
    this.tall = false,
  });

  final String title;
  final String subtitle;
  final List<Color> palette;
  final bool tall;
}

class _FeaturedClosetCard extends StatelessWidget {
  const _FeaturedClosetCard({required this.item});

  final _ClosetItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClosetImage(
            palette: item.palette,
            borderRadius: 16,
            tall: true,
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
                Icons.auto_awesome_rounded,
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
    );
  }
}

class _ClosetGridCard extends StatelessWidget {
  const _ClosetGridCard({required this.item});

  final _ClosetItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
              palette: item.palette,
              borderRadius: 14,
              tall: item.title == 'Straight Denim',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF203032),
            ),
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
    );
  }
}

class _ClosetImage extends StatelessWidget {
  const _ClosetImage({
    required this.palette,
    required this.borderRadius,
    this.tall = false,
  });

  final List<Color> palette;
  final double borderRadius;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: palette,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: tall ? 30 : 16,
              right: tall ? 30 : 16,
              top: 12,
              bottom: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            Positioned(
              left: tall ? 62 : 28,
              right: tall ? 62 : 28,
              top: tall ? 26 : 20,
              bottom: tall ? 22 : 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
