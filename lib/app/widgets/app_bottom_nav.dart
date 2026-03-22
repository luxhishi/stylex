import 'package:flutter/material.dart';

enum AppTab { home, closet, stylist, outfits }

class StylexBottomNav extends StatelessWidget {
  const StylexBottomNav({
    required this.selectedTab,
    this.onTabSelected,
    this.showAddButton = false,
    this.onAddPressed,
    super.key,
  });

  final AppTab selectedTab;
  final ValueChanged<AppTab>? onTabSelected;
  final bool showAddButton;
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    final items = const [
      _NavItemData(Icons.home_rounded, 'HOME', AppTab.home),
      _NavItemData(Icons.checkroom_outlined, 'CLOSET', AppTab.closet),
      _NavItemData(Icons.auto_awesome_rounded, 'STYLIST', AppTab.stylist),
      _NavItemData(Icons.shopping_bag_outlined, 'OUTFITS', AppTab.outfits),
    ];

    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF1FAF7),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120A7A76),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: items
                    .map(
                      (item) => Expanded(
                        child: _NavItem(
                          icon: item.icon,
                          label: item.label,
                          selected: item.tab == selectedTab,
                          onTap: () => onTabSelected?.call(item.tab),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
        if (showAddButton) ...[
          const SizedBox(width: 12),
          DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1DA79E), Color(0xFF0A7A76)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x331DA79E),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: IconButton(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NavItemData {
  const _NavItemData(this.icon, this.label, this.tab);

  final IconData icon;
  final String label;
  final AppTab tab;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = selected ? const Color(0xFF0A7A76) : const Color(0xFF8B9C9F);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFCFF6EE) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: active,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
