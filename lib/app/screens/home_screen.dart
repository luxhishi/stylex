import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/closet_item_preview.dart';
import '../services/closet_service.dart';
import '../services/recent_outfit_history_service.dart';
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
  static const _plannedOutfitsKeyPrefix = 'stylex_planned_outfits_v1';
  static const _generatedOutfitBadges = [
    'Recommended for you',
    'AI-styled for today',
    'Curated from your closet',
    'Fresh pick for you',
  ];
  static const _plannedOutfitBadges = [
    'Looking snazzy today',
    'Today\'s look is locked in',
    'Styled ahead of time',
    'Serving a planned slay',
    'Dressed and dialed in',
  ];
  static String? _cachedUserId;
  static List<ClosetItemPreview>? _cachedClosetItems;
  static List<ClosetItemPreview>? _cachedOutfitSuggestion;
  static String? _cachedPlannedOutfitDateKey;
  static List<ClosetItemPreview>? _cachedPlannedOutfitForToday;
  static String? _cachedPlannedOutfitNameForToday;
  static int _cachedSuggestionSeed = 0;

  late final HomeViewModel _viewModel;
  final ClosetService _closetService = ClosetService();
  final RecentOutfitHistoryService _recentHistoryService =
      RecentOutfitHistoryService();
  List<ClosetItemPreview> _closetItems = const [];
  List<ClosetItemPreview> _outfitSuggestion = const [];
  int _suggestionSeed = 0;
  bool _isLoadingCloset = true;
  int _recentItemsCount = 0;
  int _unusedItemsCount = 0;
  String? _unusedItemTitle;
  List<ClosetItemPreview> _plannedOutfitForToday = const [];
  String? _plannedOutfitNameForToday;

  static void clearSessionCache() {
    _cachedUserId = null;
    _cachedClosetItems = null;
    _cachedOutfitSuggestion = null;
    _cachedPlannedOutfitDateKey = null;
    _cachedPlannedOutfitForToday = null;
    _cachedPlannedOutfitNameForToday = null;
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
    if (_cachedPlannedOutfitDateKey == _dateKey(DateTime.now())) {
      _plannedOutfitForToday = _cachedPlannedOutfitForToday ?? const [];
      _plannedOutfitNameForToday = _cachedPlannedOutfitNameForToday;
    }
    _suggestionSeed = _cachedOutfitSuggestion == null
        ? DateTime.now().millisecondsSinceEpoch
        : _cachedSuggestionSeed;
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
      if (hasCache) _loadCachedInsights(),
      if (hasCache) _loadPlannedOutfitForToday(),
    ]);
  }

  Future<void> _loadClosetCount({bool preserveSuggestion = false}) async {
    if (mounted) {
      setState(() => _isLoadingCloset = true);
    }

    try {
      final items = await _closetService.fetchClosetItems();
      final insights = await _buildClosetInsights(items);
      final plannedForToday = await _resolvePlannedOutfitForToday(items);
      if (!mounted) return;
      setState(() {
        _closetItems = items;
        if (!preserveSuggestion) {
          _refreshSuggestion();
        }
        _cachedClosetItems = _closetItems;
        _cachedOutfitSuggestion = _outfitSuggestion;
        _cachedSuggestionSeed = _suggestionSeed;
        _cachedPlannedOutfitDateKey = _dateKey(DateTime.now());
        _cachedPlannedOutfitForToday = plannedForToday.items;
        _cachedPlannedOutfitNameForToday = plannedForToday.name;
        _cachedUserId = Supabase.instance.client.auth.currentUser?.id;
        _recentItemsCount = insights.recentItemsCount;
        _unusedItemsCount = insights.unusedItemsCount;
        _unusedItemTitle = insights.unusedItemTitle;
        _plannedOutfitForToday = plannedForToday.items;
        _plannedOutfitNameForToday = plannedForToday.name;
        _isLoadingCloset = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _closetItems = const [];
        _outfitSuggestion = const [];
        _cachedClosetItems = _closetItems;
        _cachedOutfitSuggestion = _outfitSuggestion;
        _cachedPlannedOutfitDateKey = _dateKey(DateTime.now());
        _cachedPlannedOutfitForToday = const [];
        _cachedPlannedOutfitNameForToday = null;
        _cachedUserId = Supabase.instance.client.auth.currentUser?.id;
        _cachedSuggestionSeed = 0;
        _recentItemsCount = 0;
        _unusedItemsCount = 0;
        _unusedItemTitle = null;
        _plannedOutfitForToday = const [];
        _plannedOutfitNameForToday = null;
        _isLoadingCloset = false;
      });
    }
  }

  Future<void> _loadPlannedOutfitForToday() async {
    final plannedForToday = await _resolvePlannedOutfitForToday(_closetItems);
    if (!mounted) return;
    setState(() {
      _plannedOutfitForToday = plannedForToday.items;
      _plannedOutfitNameForToday = plannedForToday.name;
      _cachedPlannedOutfitDateKey = _dateKey(DateTime.now());
      _cachedPlannedOutfitForToday = plannedForToday.items;
      _cachedPlannedOutfitNameForToday = plannedForToday.name;
    });
  }

  Future<void> _loadCachedInsights() async {
    final insights = await _buildClosetInsights(_closetItems);
    if (!mounted) return;
    setState(() {
      _recentItemsCount = insights.recentItemsCount;
      _unusedItemsCount = insights.unusedItemsCount;
      _unusedItemTitle = insights.unusedItemTitle;
    });
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
    );
  }

  void _openClosetFilter(String filter, {bool showUnusedFilter = false}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ClosetScreen(
          initialFilter: filter,
          showUnusedFilter: showUnusedFilter,
        ),
      ),
    );
  }

  Future<void> _storeRecentLook({
    required String title,
    required List<ClosetItemPreview> items,
    required String source,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    await _recentHistoryService.addLook(
      title: title,
      itemIds: items.map((item) => item.id).toList(),
      source: source,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('$title added to recent looks.')),
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

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  Future<_TodayPlannedOutfitData> _resolvePlannedOutfitForToday(
    List<ClosetItemPreview> items,
  ) async {
    if (items.isEmpty) {
      return const _TodayPlannedOutfitData(items: []);
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    final rawPlanned = prefs.getString('$_plannedOutfitsKeyPrefix:$currentUserId');
    if (rawPlanned == null || rawPlanned.isEmpty) {
      return const _TodayPlannedOutfitData(items: []);
    }

    try {
      final decoded = jsonDecode(rawPlanned) as Map<String, dynamic>;
      final plannedEntry = decoded[_dateKey(DateTime.now())];
      if (plannedEntry == null) {
        return const _TodayPlannedOutfitData(items: []);
      }

      final outfitId = plannedEntry is String
          ? plannedEntry
          : ((plannedEntry as Map<String, dynamic>)['outfit_id'] ??
                  plannedEntry['outfitId'])
              ?.toString();
      if (outfitId == null || outfitId.isEmpty) {
        return const _TodayPlannedOutfitData(items: []);
      }

      final rawSavedOutfits =
          prefs.getStringList('$_savedOutfitsKeyPrefix:$currentUserId') ?? const [];
      for (final entry in rawSavedOutfits) {
        try {
          final json = jsonDecode(entry) as Map<String, dynamic>;
          if ((json['created_at']?.toString() ?? '') != outfitId) {
            continue;
          }

          final itemIds = (json['item_ids'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toSet();
          final plannedItems =
              items.where((item) => itemIds.contains(item.id)).toList();
          if (plannedItems.isEmpty) {
            return const _TodayPlannedOutfitData(items: []);
          }

          return _TodayPlannedOutfitData(
            items: plannedItems,
            name: json['name']?.toString(),
          );
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      return const _TodayPlannedOutfitData(items: []);
    }

    return const _TodayPlannedOutfitData(items: []);
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
        final hasPlannedOutfitToday = _plannedOutfitForToday.isNotEmpty;
        final hasGeneratedSuggestion = _outfitSuggestion.isNotEmpty;

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
                        _SectionLabel(
                          title: 'Outfit of the Day',
                          badge: hasPlannedOutfitToday
                              ? 'PLANNED + AI PICK'
                              : _generatedOutfitBadge(),
                        ),
                        const SizedBox(height: 14),
                        if (_isLoadingCloset)
                          const _HomeLoadingCard()
                        else if (hasClosetItems)
                          Column(
                            children: [
                              if (hasPlannedOutfitToday) ...[
                                _HomeOutfitShowcaseCard(
                                  eyebrow: _plannedOutfitBadge(),
                                  title:
                                      (_plannedOutfitNameForToday?.trim().isNotEmpty ??
                                              false)
                                          ? _plannedOutfitNameForToday!
                                          : 'Planned for today',
                                  actionLabel: 'Use This Look',
                                  onAction: () {
                                    _storeRecentLook(
                                      title:
                                          (_plannedOutfitNameForToday
                                                      ?.trim()
                                                      .isNotEmpty ??
                                                  false)
                                              ? _plannedOutfitNameForToday!
                                              : 'Planned for today',
                                      items: _plannedOutfitForToday,
                                      source: 'planned',
                                    );
                                  },
                                  child: _OutfitGrid(
                                    items: _plannedOutfitForToday,
                                    showOuterwear: weather.shouldSuggestOuterwear,
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              _HomeOutfitShowcaseCard(
                                eyebrow: hasPlannedOutfitToday
                                    ? 'Fresh AI suggestion'
                                    : _generatedOutfitBadge(),
                                title: hasPlannedOutfitToday
                                    ? null
                                    : 'Recommended for you',
                                actionLabel: hasGeneratedSuggestion
                                    ? 'Use This Look'
                                    : null,
                                onAction: hasGeneratedSuggestion
                                    ? () {
                                        _storeRecentLook(
                                          title: hasPlannedOutfitToday
                                              ? 'Fresh AI suggestion'
                                              : 'Recommended for you',
                                          items: _outfitSuggestion,
                                          source: 'ai',
                                        );
                                      }
                                    : null,
                                child: hasGeneratedSuggestion
                                    ? _OutfitGrid(
                                        items: _outfitSuggestion,
                                        showOuterwear:
                                            weather.shouldSuggestOuterwear,
                                      )
                                    : const _OutfitSuggestionUnavailableCard(),
                              ),
                            ],
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
                                  await _loadPlannedOutfitForToday();
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
                                    _openClosetFilter(
                                      'Unused',
                                      showUnusedFilter: true,
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
                                    _openClosetFilter('Recently Added');
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

  String _generatedOutfitBadge() {
    final phrases = _generatedOutfitBadges;
    final now = DateTime.now();
    final todaySeed = now.year * 10000 + now.month * 100 + now.day;
    final extraSeed = _suggestionSeed;
    final index = (todaySeed + extraSeed.abs()) % phrases.length;
    return phrases[index];
  }

  String _plannedOutfitBadge() {
    final now = DateTime.now();
    final todaySeed = now.year * 10000 + now.month * 100 + now.day;
    final extraSeed = _plannedOutfitNameForToday?.length ?? 0;
    final index = (todaySeed + extraSeed) % _plannedOutfitBadges.length;
    return _plannedOutfitBadges[index];
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

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF182628),
          ),
        ),
        if (badge != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              badge!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF0A8C87),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.35,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeOutfitShowcaseCard extends StatelessWidget {
  const _HomeOutfitShowcaseCard({
    required this.eyebrow,
    this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String eyebrow;
  final String? title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAF9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0ECE9)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF0A8C87),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.45,
              ),
            ),
            if (title != null && title!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF1F2B2D),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onAction,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0A8C87),
                    side: const BorderSide(color: Color(0xFFBFE2DD)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                  label: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
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

class _OutfitSuggestionUnavailableCard extends StatelessWidget {
  const _OutfitSuggestionUnavailableCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1EEEB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              color: Color(0xFF0A7A76),
              size: 24,
            ),
            const SizedBox(height: 10),
            Text(
              'We need a few more pieces to build a fresh suggestion.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF1F2B2D),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add a mix of tops, bottoms, and shoes to unlock more generated looks.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6A7C7E),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
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

// ignore: unused_element
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

class _TrendingCard extends StatefulWidget {
  const _TrendingCard();

  @override
  State<_TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends State<_TrendingCard> {
  static const _items = [
    _TrendingCombination(
      title: 'The Modern Explorer',
      label: 'CASUAL - 85% MATCH',
      sideLabel: 'METRO FORM',
      backgroundColors: [Color(0xFFF7DFD7), Color(0xFFF4EEE8)],
      orbColors: [Color(0xFF4D2E20), Color(0xFF1D130D)],
    ),
    _TrendingCombination(
      title: 'Soft Power Layers',
      label: 'SMART - 92% MATCH',
      sideLabel: 'CITY EDIT',
      backgroundColors: [Color(0xFFDDEFEA), Color(0xFFF4FBF8)],
      orbColors: [Color(0xFF41685E), Color(0xFF203A35)],
    ),
    _TrendingCombination(
      title: 'Weekend Minimal',
      label: 'EASY - 88% MATCH',
      sideLabel: 'OFF DUTY',
      backgroundColors: [Color(0xFFE3ECFF), Color(0xFFF4F7FF)],
      orbColors: [Color(0xFF294C82), Color(0xFF18263F)],
    ),
  ];

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % _items.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = _items[_index];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: ClipRRect(
        key: ValueKey(item.title),
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 170,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: item.backgroundColors,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 18,
                        right: 18,
                        top: 14,
                        bottom: 42,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: item.orbColors),
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
                                  item.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1F2A2C),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.label,
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
                        item.sideLabel,
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
      ),
    );
  }
}

class _ClosetInsightsData {
  const _ClosetInsightsData({
    required this.recentItemsCount,
    required this.unusedItemsCount,
    required this.unusedItemTitle,
  });

  final int recentItemsCount;
  final int unusedItemsCount;
  final String? unusedItemTitle;
}

class _TodayPlannedOutfitData {
  const _TodayPlannedOutfitData({
    required this.items,
    this.name,
  });

  final List<ClosetItemPreview> items;
  final String? name;
}

class _TrendingCombination {
  const _TrendingCombination({
    required this.title,
    required this.label,
    required this.sideLabel,
    required this.backgroundColors,
    required this.orbColors,
  });

  final String title;
  final String label;
  final String sideLabel;
  final List<Color> backgroundColors;
  final List<Color> orbColors;
}
