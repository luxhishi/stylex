import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  static void clearSessionCache() {
    _HomeScreenState.clearSessionCache();
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _savedOutfitsKeyPrefix = 'stylex_saved_outfits_v2';
  static String? _cachedUserId;
  static List<ClosetItemPreview>? _cachedClosetItems;
  static List<ClosetItemPreview>? _cachedOutfitSuggestion;
  static int _cachedSuggestionSeed = 0;

  late final HomeViewModel _viewModel;
  final ClosetService _closetService = ClosetService();
  List<ClosetItemPreview> _closetItems = const [];
  List<ClosetItemPreview> _outfitSuggestion = const [];
  int _suggestionSeed = 0;
  bool _isLoadingCloset = true;
  int _recentItemsCount = 0;
  int _unusedItemsCount = 0;
  String? _unusedItemTitle;
  List<ClosetItemPreview> _recentItems = const [];
  List<ClosetItemPreview> _unusedItems = const [];

  static void clearSessionCache() {
    _cachedUserId = null;
    _cachedClosetItems = null;
    _cachedOutfitSuggestion = null;
    _cachedSuggestionSeed = 0;
  }

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (_cachedUserId != currentUserId) {
      clearSessionCache();
      _cachedUserId = currentUserId;
    }
    _closetItems = _cachedClosetItems ?? const [];
    _outfitSuggestion = _cachedOutfitSuggestion ?? const [];
    _suggestionSeed = _cachedSuggestionSeed;
    _isLoadingCloset = _cachedClosetItems == null;
    _initializeHome();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _initializeHome() async {
    final hasCache = _cachedClosetItems != null && _cachedOutfitSuggestion != null;
    await Future.wait([
      _viewModel.load(forceRefresh: false),
      if (!hasCache) _loadClosetCount(),
    ]);
  }

  Future<void> _loadClosetCount({bool preserveSuggestion = false}) async {
    if (mounted) {
      setState(() => _isLoadingCloset = true);
    }

    try {
      final items = await _closetService.fetchClosetItems();
      final insights = await _buildClosetInsights(items);
      if (!mounted) return;
      setState(() {
        _closetItems = items;
        if (!preserveSuggestion) {
          _refreshSuggestion();
        }
        _cachedClosetItems = _closetItems;
        _cachedOutfitSuggestion = _outfitSuggestion;
        _cachedSuggestionSeed = _suggestionSeed;
        _cachedUserId = Supabase.instance.client.auth.currentUser?.id;
        _recentItemsCount = insights.recentItemsCount;
        _unusedItemsCount = insights.unusedItemsCount;
        _unusedItemTitle = insights.unusedItemTitle;
        _recentItems = insights.recentItems;
        _unusedItems = insights.unusedItems;
        _isLoadingCloset = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _closetItems = const [];
        _outfitSuggestion = const [];
        _cachedClosetItems = _closetItems;
        _cachedOutfitSuggestion = _outfitSuggestion;
        _cachedUserId = Supabase.instance.client.auth.currentUser?.id;
        _cachedSuggestionSeed = 0;
        _recentItemsCount = 0;
        _unusedItemsCount = 0;
        _unusedItemTitle = null;
        _recentItems = const [];
        _unusedItems = const [];
        _isLoadingCloset = false;
      });
    }
  }

  Future<_ClosetInsightsData> _buildClosetInsights(
    List<ClosetItemPreview> items,
  ) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('$_savedOutfitsKeyPrefix:$currentUserId') ?? const [];

    final savedItemIds = <String>{};
    for (final entry in raw) {
      try {
        final json = jsonDecode(entry) as Map<String, dynamic>;
        final ids = (json['item_ids'] as List<dynamic>? ?? const [])
            .map((item) => item.toString());
        savedItemIds.addAll(ids);
      } catch (_) {
        continue;
      }
    }

    final unusedItems = items.where((item) => !savedItemIds.contains(item.id)).toList();
    final now = DateTime.now();
    final recentThreshold = now.subtract(const Duration(days: 7));
    final recentItemsCount = items.where((item) {
      final createdAt = item.createdAt;
      if (createdAt == null) return false;
      return createdAt.isAfter(recentThreshold);
    }).length;

    return _ClosetInsightsData(
      recentItemsCount: recentItemsCount,
      unusedItemsCount: unusedItems.length,
      unusedItemTitle: unusedItems.isNotEmpty ? unusedItems.first.title : null,
      recentItems: items.where((item) {
        final createdAt = item.createdAt;
        if (createdAt == null) return false;
        return createdAt.isAfter(recentThreshold);
      }).toList(),
      unusedItems: unusedItems,
    );
  }

  void _showInsightItemsSheet({
    required String title,
    required String emptyMessage,
    required List<ClosetItemPreview> items,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 60, 14, 14),
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
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF203032),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        emptyMessage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF708082),
                          height: 1.45,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 340,
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _InsightItemTile(item: items[index]);
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
                        if (_isLoadingCloset)
                          const _HomeLoadingCard()
                        else if (hasClosetItems)
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
                                if (!context.mounted) return;
                                if (hasClosetItems) {
                                  setState(() {
                                    _suggestionSeed++;
                                    _refreshSuggestion();
                                    _cachedClosetItems = _closetItems;
                                  });
                                } else if (!_isLoadingCloset) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const ClosetScreen(),
                                    ),
                                  );
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
                                        : _isLoadingCloset
                                            ? 'Loading Your Closet'
                                            : 'Go To Closet',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const _SectionLabel(title: 'Closet Insights'),
                        const SizedBox(height: 14),
                        if (_isLoadingCloset)
                          const _HomeLoadingInsightsCard()
                        else if (hasClosetItems)
                          Row(
                            children: [
                              Expanded(
                                child: _InsightCard(
                                  icon: Icons.auto_awesome_rounded,
                                  title: 'AI Stylist',
                                  body: _unusedItemsCount == 0
                                      ? 'Every closet piece has already been used in a saved look.'
                                      : _unusedItemTitle != null
                                          ? '$_unusedItemsCount pieces have not been used yet. Try styling $_unusedItemTitle next.'
                                          : '$_unusedItemsCount pieces have not been used in a saved outfit yet.',
                                  onTap: () {
                                    _showInsightItemsSheet(
                                      title: 'Unused Closet Pieces',
                                      emptyMessage:
                                          'Every closet piece has already been used in a saved outfit.',
                                      items: _unusedItems,
                                    );
                                  },
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _InsightCard(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'Recent Items',
                                  body: _recentItemsCount == 0
                                      ? 'No new items added in the last 7 days.'
                                      : _recentItemsCount == 1
                                          ? 'You added 1 item in the last 7 days.'
                                          : 'You added $_recentItemsCount items in the last 7 days.',
                                  onTap: () {
                                    _showInsightItemsSheet(
                                      title: 'Recently Added Pieces',
                                      emptyMessage:
                                          'No new items were added in the last 7 days.',
                                      items: _recentItems,
                                    );
                                  },
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

class _HomeLoadingCard extends StatelessWidget {
  const _HomeLoadingCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1EEEB)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: Color(0xFF0A7A76),
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Loading your closet pieces...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1F2B2D),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'We are preparing your outfit suggestions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6A7C7E),
                fontSize: 13,
                height: 1.4,
              ),
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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
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
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF0A7A76), size: 18),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFA8B6B6),
                    size: 18,
                  ),
                ],
              ),
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

class _HomeLoadingInsightsCard extends StatelessWidget {
  const _HomeLoadingInsightsCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1EEEB)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Color(0xFF0A7A76),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Loading closet insights...',
                style: TextStyle(
                  color: Color(0xFF708082),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightItemTile extends StatelessWidget {
  const _InsightItemTile({required this.item});

  final ClosetItemPreview item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3ECE9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item.imageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFEAF2F0),
                    ),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(
                        Icons.checkroom_outlined,
                        color: Color(0xFF7B8D90),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF233234),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.category.toUpperCase()} • ${item.subtitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8A999C),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
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

class _ClosetInsightsData {
  const _ClosetInsightsData({
    required this.recentItemsCount,
    required this.unusedItemsCount,
    required this.unusedItemTitle,
    required this.recentItems,
    required this.unusedItems,
  });

  final int recentItemsCount;
  final int unusedItemsCount;
  final String? unusedItemTitle;
  final List<ClosetItemPreview> recentItems;
  final List<ClosetItemPreview> unusedItems;
}
