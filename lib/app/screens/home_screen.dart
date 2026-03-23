import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/closet_item_preview.dart';
import '../services/closet_service.dart';
import '../view_models/home_view_model.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/onboarding_shell.dart';
import 'closet_screen.dart';
import 'outfits_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static List<ClosetItemPreview>? _cachedClosetItems;
  static List<ClosetItemPreview>? _cachedOutfitSuggestion;
  static int _cachedSuggestionSeed = 0;

  late final HomeViewModel _viewModel;
  final ClosetService _closetService = ClosetService();
  List<ClosetItemPreview> _closetItems = const [];
  List<ClosetItemPreview> _outfitSuggestion = const [];
  int _suggestionSeed = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel();
    _closetItems = _cachedClosetItems ?? const [];
    _outfitSuggestion = _cachedOutfitSuggestion ?? const [];
    _suggestionSeed = _cachedSuggestionSeed;
    _initializeHome();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _initializeHome() async {
    final hasCache = _cachedClosetItems != null && _cachedOutfitSuggestion != null;
    await _viewModel.load(forceRefresh: false);
    if (!hasCache) {
      await _loadClosetCount();
    }
  }

  Future<void> _loadClosetCount({bool preserveSuggestion = false}) async {
    try {
      final items = await _closetService.fetchClosetItems();
      if (!mounted) return;
      setState(() {
        _closetItems = items;
        if (!preserveSuggestion) {
          _refreshSuggestion();
        }
        _cachedClosetItems = _closetItems;
        _cachedOutfitSuggestion = _outfitSuggestion;
        _cachedSuggestionSeed = _suggestionSeed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _closetItems = const [];
        _outfitSuggestion = const [];
        _cachedClosetItems = _closetItems;
        _cachedOutfitSuggestion = _outfitSuggestion;
        _cachedSuggestionSeed = 0;
      });
    }
  }

  void _refreshSuggestion() {
    _outfitSuggestion = _closetService.buildOutfitSuggestion(
      items: _closetItems,
      includeOuterwear: _viewModel.state.shouldSuggestOuterwear,
      seed: _suggestionSeed,
    );
    _cachedOutfitSuggestion = _outfitSuggestion;
    _cachedSuggestionSeed = _suggestionSeed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = Supabase.instance.client.auth.currentUser;
    final firstName = _resolveFirstName(currentUser);

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final weather = _viewModel.state;
        final hasClosetItems = _closetItems.isNotEmpty;

        return Scaffold(
          body: AppViewport(
            child: AppPanel(
              padding: EdgeInsets.zero,
              clip: true,
              borderRadius: 0,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 118),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(theme: theme),
                        const SizedBox(height: 22),
                        Text(
                          '${weather.greeting},\n$firstName!',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 37,
                            fontWeight: FontWeight.w800,
                            height: 0.95,
                            letterSpacing: -1.5,
                            color: const Color(0xFF1F2B2D),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              weather.icon,
                              size: 18,
                              color: const Color(0xFF0A7A76),
                            ),
                            if (weather.temperatureLabel != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                weather.temperatureLabel!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF0A7A76),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                weather.message,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF5D6E70),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const _SectionLabel(
                          title: 'Outfit of the Day',
                          badge: 'RECOMMENDED FOR YOU',
                        ),
                        const SizedBox(height: 14),
                        if (hasClosetItems)
                          _OutfitGrid(
                            items: _outfitSuggestion,
                            showOuterwear: weather.shouldSuggestOuterwear,
                          )
                        else
                          _EmptyHomeSuggestionCard(
                            onAddPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ClosetScreen(),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF0A8C87),
                                  Color(0xFF6CF4ED),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x330A8C87),
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: FilledButton.icon(
                              onPressed: () async {
                                await _viewModel.load(forceRefresh: true);
                                if (!mounted) return;
                                if (hasClosetItems) {
                                  setState(() {
                                    _suggestionSeed++;
                                    _refreshSuggestion();
                                    _cachedClosetItems = _closetItems;
                                  });
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              icon: Icon(
                                weather.isLoading
                                    ? Icons.sync_rounded
                                    : Icons.refresh_rounded,
                                size: 18,
                              ),
                              label: Text(
                                weather.isLoading
                                    ? 'Refreshing Style Weather'
                                    : hasClosetItems
                                        ? 'Get Another Suggestion'
                                        : 'Go To Closet',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const _SectionLabel(title: 'Closet Insights'),
                        const SizedBox(height: 14),
                        if (hasClosetItems)
                          const Row(
                            children: [
                              Expanded(
                                child: _InsightCard(
                                  icon: Icons.auto_awesome_rounded,
                                  title: 'AI Stylist',
                                  body:
                                      '3 new pairings found for your favorite blazer.',
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _InsightCard(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'Recent Items',
                                  body: 'You added 5 items this week.',
                                ),
                              ),
                            ],
                          )
                        else
                          const _EmptyInsightCard(),
                        const SizedBox(height: 28),
                        const _SectionLabel(title: 'Trending Combinations'),
                        const SizedBox(height: 14),
                        const _TrendingCard(),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: StylexBottomNav(
                      selectedTab: AppTab.home,
                      onTabSelected: (tab) {
                        if (tab == AppTab.home) {
                          return;
                        }

                        if (tab == AppTab.closet) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => const ClosetScreen(),
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
                      },
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

  String _resolveFirstName(User? user) {
    final fullName =
        (user?.userMetadata?['full_name'] as String?)?.trim() ?? '';
    if (fullName.isNotEmpty) {
      return fullName.split(RegExp(r'\s+')).first;
    }

    final email = user?.email?.trim() ?? '';
    if (email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'there';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
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
          'Stylex',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0A6E6A),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.badge});

  final String title;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF182628),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              badge!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF0A8C87),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OutfitGrid extends StatelessWidget {
  const _OutfitGrid({
    required this.items,
    required this.showOuterwear,
  });

  final List<ClosetItemPreview> items;
  final bool showOuterwear;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final top = items.firstOrNull;
    final bottom = items.length > 1 ? items[1] : null;
    final shoe = items.length > 2 ? items[2] : null;
    final outerwear = items.length > 3 ? items[3] : null;

    return Column(
      children: [
        SizedBox(
          height: 196,
          child: Row(
            children: [
              Expanded(
                child: top != null
                    ? _OutfitCard(item: top, tall: true)
                    : const _OutfitPlaceholderCard(
                        title: 'Add a top',
                        subtitle: 'A complete outfit starts with one core piece.',
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: bottom != null
                          ? _OutfitCard(item: bottom)
                          : const _OutfitPlaceholderCard(
                              title: 'Add bottoms',
                              subtitle: 'We will match them with your tops.',
                            ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: shoe != null
                          ? _OutfitCard(item: shoe)
                          : const _OutfitPlaceholderCard(
                              title: 'Add shoes',
                              subtitle: 'Footwear completes the suggestion.',
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showOuterwear) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            width: double.infinity,
            child: outerwear != null
                ? _LayerSuggestionCard(item: outerwear)
                : const _OutfitPlaceholderCard(
                    title: 'No outerwear match yet',
                    subtitle: 'Add a jacket or coat for cold or wet days.',
                    compact: true,
                  ),
          ),
        ],
      ],
    );
  }
}

class _EmptyHomeSuggestionCard extends StatelessWidget {
  const _EmptyHomeSuggestionCard({required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1EEEB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              color: Color(0xFF0A7A76),
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              'Nothing to see here... add your first item.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1F2B2D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Outfit suggestions will show up once your closet has at least one piece to work with.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6A7C7E),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAddPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0A7A76),
                side: const BorderSide(color: Color(0xFFBFE6DE)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add First Item'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutfitCard extends StatelessWidget {
  const _OutfitCard({
    required this.item,
    this.tall = false,
  });

  final ClosetItemPreview item;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
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
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFEAF3F1), Color(0xFFD7E7E3)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFF6D7E80),
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
                  Colors.black.withValues(alpha: tall ? 0.14 : 0.24),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE8F6F4),
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutfitPlaceholderCard extends StatelessWidget {
  const _OutfitPlaceholderCard({
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1EEEB)),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF0A7A76),
              size: 18,
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF203032),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF6A7C7E),
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerSuggestionCard extends StatelessWidget {
  const _LayerSuggestionCard({required this.item});

  final ClosetItemPreview item;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
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
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFFEAF3F1), Color(0xFFD7E7E3)],
                  ),
                ),
              );
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'LAYER OPTION',
                  style: TextStyle(
                    color: Color(0xFFCFF6EE),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    color: Color(0xFFE7F2F0),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EFEA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF0A7A76), size: 18),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF708082),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInsightCard extends StatelessWidget {
  const _EmptyInsightCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1EEEB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFDFF4EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_outlined,
                color: Color(0xFF0A7A76),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No closet insights yet',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1F2B2D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add your first piece and we will start surfacing insights here.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF708082),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 170,
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF7DFD7),
                      Color(0xFFF4EEE8),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      left: 18,
                      right: 18,
                      top: 14,
                      bottom: 42,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF4D2E20), Color(0xFF1D130D)],
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'The Modern Explorer',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1F2A2C),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'CASUAL - 85% MATCH',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFF6E8F95),
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Center(
                    child: Text(
                      'METRO FORM',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF98A8AA),
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
