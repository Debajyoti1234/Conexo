import 'package:flutter/material.dart';

class ConexoButton extends StatelessWidget {
  const ConexoButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    width: double.infinity,
    child: FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
    ),
  );
}

class ConexoTextField extends StatefulWidget {
  const ConexoTextField({
    required this.controller,
    required this.label,
    required this.icon,
    super.key,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;

  @override
  State<ConexoTextField> createState() => _ConexoTextFieldState();
}

class _ConexoTextFieldState extends State<ConexoTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.obscureText;
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: isPassword && _obscured,
      autocorrect: !isPassword,
      enableSuggestions: !isPassword,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon),
        suffixIcon: isPassword
            ? IconButton(
                tooltip: _obscured ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
      ),
    );
  }
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.title, required this.subtitle, super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withValues(alpha: .18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.people_alt_rounded, color: Color(0xFFB7A5FF)),
      ),
      const SizedBox(height: 28),
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: const Color(0xFFAFB8D4)),
      ),
    ],
  );
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.name,
    super.key,
    this.size = 44,
    this.online = false,
    this.color = const Color(0xFF8B5CF6),
  });
  final String name;
  final double size;
  final bool online;
  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      CircleAvatar(
        radius: size / 2,
        backgroundColor: color,
        child: Text(
          name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontSize: size * .36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      if (online)
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            height: size * .27,
            width: size * .27,
            decoration: BoxDecoration(
              color: const Color(0xFF47D7A5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0B1020), width: 2),
            ),
          ),
        ),
    ],
  );
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    required this.label,
    required this.icon,
    super.key,
    this.selected = false,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    avatar: Icon(
      icon,
      size: 17,
      color: selected ? Colors.white : const Color(0xFFB7A5FF),
    ),
    selected: selected,
    onSelected: (_) => onTap?.call(),
    selectedColor: const Color(0xFF7659DF),
    backgroundColor: const Color(0xFF171F35),
    side: BorderSide(
      color: selected ? Colors.transparent : const Color(0xFF2C3650),
    ),
    labelStyle: TextStyle(
      color: selected ? Colors.white : const Color(0xFFDDE3F4),
      fontWeight: FontWeight.w600,
    ),
  );
}

class PlanSearchBar extends StatelessWidget {
  const PlanSearchBar({
    super.key,
    this.hint = 'Search plans, people, places',
    this.onChanged,
  });
  final String hint;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: IconButton(
        onPressed: () {},
        icon: const Icon(Icons.tune_rounded),
        tooltip: 'Filter',
      ),
    ),
  );
}

class PlanCard extends StatelessWidget {
  const PlanCard({
    required this.title,
    required this.category,
    required this.date,
    required this.location,
    super.key,
    this.compact = false,
    this.color = const Color(0xFF7659DF),
  });
  final String title;
  final String category;
  final String date;
  final String location;
  final bool compact;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: compact ? 210 : null,
    decoration: BoxDecoration(
      color: const Color(0xFF171F35),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFF28324B)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: compact ? 122 : 142,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: .5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 14,
                top: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: 16,
                child: Icon(
                  _categoryIcon(category),
                  size: 44,
                  color: Colors.white.withValues(alpha: .9),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Color(0xFFAEB9D6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      date,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFAEB9D6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Color(0xFFAEB9D6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFAEB9D6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xFF182039).withValues(alpha: .78),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: .09)),
    ),
    child: child,
  );
}

class InterestChip extends StatelessWidget {
  const InterestChip({
    required this.label,
    required this.icon,
    super.key,
    this.selected = false,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) =>
      CategoryChip(label: label, icon: icon, selected: selected, onTap: onTap);
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Music':
      return Icons.music_note_rounded;
    case 'Food':
      return Icons.restaurant_rounded;
    case 'Tech':
      return Icons.memory_rounded;
    default:
      return Icons.celebration_rounded;
  }
}

class ProfileStatCard extends StatelessWidget {
  const ProfileStatCard({required this.value, required this.label, super.key});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF171F35),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFFAEB9D6)),
        ),
      ],
    ),
  );
}
