import 'package:flutter/material.dart';

/// Admin sidebar navigation.
///
/// Persistent on desktop. Collapses to a narrow rail on smaller widths
/// or when [collapsed] is true.
class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    required this.sectionTitles,
    required this.sectionIcons,
    required this.selectedIndex,
    required this.onSectionSelected,
    required this.onToggle,
    required this.onSignOut,
    this.collapsed = false,
    super.key,
  });

  final List<String> sectionTitles;
  final List<IconData> sectionIcons;
  final int selectedIndex;
  final ValueChanged<int> onSectionSelected;
  final VoidCallback onToggle;
  final VoidCallback onSignOut;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: collapsed ? 72 : 240,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1120),
        border: Border(
          right: BorderSide(color: Color(0xFF1E2438)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: collapsed
                ? _BrandCompact(onToggle: onToggle)
                : _BrandExpanded(onToggle: onToggle),
          ),
          const Divider(height: 1, color: Color(0xFF1E2438)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: sectionTitles.length,
              itemBuilder: (context, index) {
                final isSelected = index == selectedIndex;
                return _SidebarItem(
                  label: sectionTitles[index],
                  icon: sectionIcons[index],
                  selected: isSelected,
                  collapsed: collapsed,
                  onTap: () => onSectionSelected(index),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1E2438)),
          _SidebarItem(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            selected: false,
            collapsed: collapsed,
            onTap: onSignOut,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _BrandExpanded extends StatelessWidget {
  const _BrandExpanded({required this.onToggle});
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF9D82FF).withValues(alpha: 0.4),
            ),
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            size: 20,
            color: Color(0xFFB7A5FF),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONEXO ADMIN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Color(0xFFE9E2FF),
                ),
              ),
              Text(
                'Owner console',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF7E88A8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onToggle,
          icon: const Icon(Icons.chevron_left_rounded, size: 18),
          color: const Color(0xFF7E88A8),
          tooltip: 'Collapse',
        ),
      ],
    );
  }
}

class _BrandCompact extends StatelessWidget {
  const _BrandCompact({required this.onToggle});
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onToggle,
      icon: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF9D82FF).withValues(alpha: 0.4),
          ),
        ),
        child: const Icon(
          Icons.admin_panel_settings_rounded,
          size: 20,
          color: Color(0xFFB7A5FF),
        ),
      ),
      tooltip: 'Expand sidebar',
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

final String label;
  final  IconData icon;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: widget.selected
            ? const Color(0xFF8B5CF6).withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          leading: Icon(
            widget.icon,
            size: 20,
            color: widget.selected
                ? const Color(0xFFB7A5FF)
                : const Color(0xFF7E88A8),
          ),
          title: widget.collapsed
              ? null
              : Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                    color: widget.selected
                        ? const Color(0xFFE9E2FF)
                        : const Color(0xFF9AA3C2),
                  ),
                ),
          onTap: widget.onTap,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}














