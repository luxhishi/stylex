import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../view_models/home_view_model.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/onboarding_shell.dart';
import 'closet_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel();
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
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
                        const _OutfitGrid(),
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
                              onPressed: () {
                                _viewModel.load();
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
                                    : 'Get Another Suggestion',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const _SectionLabel(title: 'Closet Insights'),
                        const SizedBox(height: 14),
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
                        ),
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
          onPressed: () {},
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
        const Spacer(),
        IconButton(
          onPressed: () {},
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFE8F5F2),
            foregroundColor: const Color(0xFF0A7A76),
          ),
          icon: const Icon(Icons.settings_rounded),
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
  const _OutfitGrid();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 196,
      child: Row(
        children: [
          Expanded(
            child: _OutfitCard(
              label: 'Linen Tailored Shirt',
              colors: [Color(0xFF36544A), Color(0xFFE7E2D9)],
              tall: true,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _OutfitCard(
                    label: 'Cotton Chino',
                    colors: [Color(0xFFC88B2E), Color(0xFFF6F0E8)],
                  ),
                ),
                SizedBox(height: 10),
                Expanded(
                  child: _OutfitCard(
                    label: 'Minimalist Low-tops',
                    colors: [Color(0xFF0F1E23), Color(0xFFECECEA)],
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

class _OutfitCard extends StatelessWidget {
  const _OutfitCard({
    required this.label,
    required this.colors,
    this.tall = false,
  });

  final String label;
  final List<Color> colors;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
            ),
          ),
          if (tall)
            const Positioned(
              top: 12,
              left: 18,
              right: 18,
              bottom: 26,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFF7F1E8),
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
              ),
            ),
          if (tall)
            const Positioned(
              top: 28,
              left: 38,
              right: 38,
              bottom: 36,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFDDD5C8),
                  borderRadius: BorderRadius.all(Radius.circular(22)),
                ),
              ),
            ),
          if (!tall)
            const Positioned(
              left: 14,
              right: 14,
              top: 18,
              bottom: 18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x22FFFFFF),
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
              ),
            ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Text(
              label,
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
