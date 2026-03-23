import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/onboarding_shell.dart';
import 'auth_screen.dart';
import 'closet_screen.dart';
import 'home_screen.dart';
import 'outfits_screen.dart';
import 'style_preference_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _notificationsEnabled = true;
  var _smartSortingEnabled = true;
  var _isSigningOut = false;

  Future<void> _openStylePreference() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const StylePreferenceScreen(),
      ),
    );
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is coming soon.')),
    );
  }

  Future<void> _handleSignOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);

    try {
      if (SupabaseConfig.isConfigured) {
        await Supabase.instance.client.auth.signOut();
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const AuthScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Log out failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  void _handleTabSelection(AppTab tab) {
    if (tab == AppTab.home) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
        ),
      );
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = SupabaseConfig.isConfigured
        ? Supabase.instance.client.auth.currentUser
        : null;
    final displayName = _resolveDisplayName(currentUser);
    final accountSubtitle = currentUser?.email?.trim().isNotEmpty == true
        ? currentUser!.email!.trim()
        : 'Profile, email, and security';

    return Scaffold(
      body: AppViewport(
        child: AppPanel(
          padding: EdgeInsets.zero,
          borderRadius: 0,
          clip: true,
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 136),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingsHeader(
                      displayName: displayName,
                      onBackPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Settings',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF243335),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Personalize your digital styling experience',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8C9A9D),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SettingsCard(
                      child: _SettingsTile(
                        icon: Icons.person_rounded,
                        iconBackground: const Color(0xFFE4F5F1),
                        iconColor: const Color(0xFF0A7A76),
                        title: 'Account Management',
                        subtitle: accountSubtitle,
                        onTap: () => _showComingSoon('Account management'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _SectionLabel(title: 'CURATION'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.auto_awesome_rounded,
                            iconBackground: const Color(0xFFE6F8F5),
                            iconColor: const Color(0xFF1A9D95),
                            title: 'Style Preferences',
                            subtitle: 'Minimalist and tidy',
                            onTap: _openStylePreference,
                          ),
                          const _TileDivider(),
                          _SettingsTile(
                            icon: Icons.thermostat_rounded,
                            iconBackground: const Color(0xFFE3F6F7),
                            iconColor: const Color(0xFF2A97A0),
                            title: 'Weather Settings',
                            subtitle: 'Location and temperature',
                            trailingLabel: 'Celsius',
                            onTap: () => _showComingSoon('Weather settings'),
                          ),
                          const _TileDivider(),
                          _SettingsSwitchTile(
                            icon: Icons.auto_fix_high_rounded,
                            iconBackground: const Color(0xFFE4F2FB),
                            iconColor: const Color(0xFF4A8FC7),
                            title: 'AI Smart Sorting',
                            subtitle: 'Intelligent wardrobe organizing',
                            value: _smartSortingEnabled,
                            onChanged: (value) {
                              setState(() => _smartSortingEnabled = value);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _SectionLabel(title: 'PRIVACY & APP'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      child: Column(
                        children: [
                          _SettingsSwitchTile(
                            icon: Icons.notifications_rounded,
                            iconBackground: const Color(0xFFE4F7F1),
                            iconColor: const Color(0xFF2A9E7A),
                            title: 'Notifications',
                            subtitle: 'Daily outfit ideas and reminders',
                            value: _notificationsEnabled,
                            onChanged: (value) {
                              setState(() => _notificationsEnabled = value);
                            },
                          ),
                          const _TileDivider(),
                          _SettingsTile(
                            icon: Icons.lock_rounded,
                            iconBackground: const Color(0xFFEAF3F1),
                            iconColor: const Color(0xFF4A6E71),
                            title: 'Privacy',
                            subtitle: 'Data sharing and visibility',
                            onTap: () => _showComingSoon('Privacy settings'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9EFEF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TextButton(
                          onPressed: _isSigningOut ? null : _handleSignOut,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD45F5D),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSigningOut
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFD45F5D),
                                  ),
                                )
                              : const Text(
                                  'Log Out',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
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
                  selectedTab: AppTab.home,
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

    return 'Stylex';
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.displayName,
    required this.onBackPressed,
  });

  final String displayName;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
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
              onPressed: onBackPressed,
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
            _AvatarBadge(label: displayName),
          ],
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final parts = label
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? 'S'
        : parts.take(2).map((part) => part[0].toUpperCase()).join();

    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFF3D6B4), Color(0xFFDDAA86)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF9BA8AB),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5ECEB)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: child,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingLabel,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        child: Row(
          children: [
            _TileIcon(
              icon: icon,
              background: iconBackground,
              color: iconColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF253537),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8B999B),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingLabel != null) ...[
              Text(
                trailingLabel!,
                style: const TextStyle(
                  color: Color(0xFF4E9FA2),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFB4BEBF),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      child: Row(
        children: [
          _TileIcon(
            icon: icon,
            background: iconBackground,
            color: iconColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF253537),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8B999B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF0A7A76),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD0DADA),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({
    required this.icon,
    required this.background,
    required this.color,
  });

  final IconData icon;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 15),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 40),
      child: Divider(
        height: 1,
        color: Color(0xFFE3EAE9),
      ),
    );
  }
}
