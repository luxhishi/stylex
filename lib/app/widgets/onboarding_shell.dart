import 'package:flutter/material.dart';

class SoftBackground extends StatelessWidget {
  const SoftBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEAF6F3),
            Color(0xFFF8FBFA),
            Color(0xFFE9F6F4),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -70,
            right: -30,
            child: BlurBlob(size: 190, color: Color(0xFFC5F3EE)),
          ),
          const Positioned(
            bottom: 100,
            left: -50,
            child: BlurBlob(size: 210, color: Color(0xFFE1F6F0)),
          ),
          child,
        ],
      ),
    );
  }
}

class BlurBlob extends StatelessWidget {
  const BlurBlob({
    required this.size,
    required this.color,
    super.key,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.9),
              blurRadius: 60,
              spreadRadius: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A7A76),
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AppViewport extends StatelessWidget {
  const AppViewport({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SoftBackground(
      child: SafeArea(
        child: Padding(
          padding: padding,
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.clip = false,
    this.borderRadius = 0,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool clip;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      width: double.infinity,
      height: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );

    if (!clip) return panel;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: panel,
    );
  }
}

class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeftSelected,
    required this.onChanged,
    super.key,
  });

  final String leftLabel;
  final String rightLabel;
  final bool isLeftSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: SegmentButton(
              label: leftLabel,
              selected: isLeftSelected,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: SegmentButton(
              label: rightLabel,
              selected: !isLeftSelected,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class SegmentButton extends StatelessWidget {
  const SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF2D3A3C),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF697779),
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class StyledInput extends StatefulWidget {
  const StyledInput({
    required this.hintText,
    required this.icon,
    this.controller,
    this.trailing,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    super.key,
  });

  final String hintText;
  final IconData icon;
  final TextEditingController? controller;
  final IconData? trailing;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  State<StyledInput> createState() => _StyledInputState();
}

class _StyledInputState extends State<StyledInput> {
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _isObscured,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFDCE9E7),
        hintText: widget.hintText,
        hintStyle: const TextStyle(color: Color(0xFF748182)),
        prefixIcon: Icon(widget.icon, color: const Color(0xFF6B797A)),
        suffixIcon: widget.trailing == null
            ? null
            : IconButton(
                onPressed: widget.obscureText
                    ? () {
                        setState(() => _isObscured = !_isObscured);
                      }
                    : null,
                icon: Icon(
                  widget.obscureText
                      ? (_isObscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined)
                      : widget.trailing,
                  color: const Color(0xFF6B797A),
                ),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  const SocialButton({
    required this.icon,
    required this.label,
    super.key,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFFF3F8F7),
        foregroundColor: const Color(0xFF425254),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class StyleCardData {
  const StyleCardData(this.title, this.subtitle, {this.wide = false});

  final String title;
  final String subtitle;
  final bool wide;
}

class PreferenceTile extends StatelessWidget {
  const PreferenceTile({
    required this.data,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final StyleCardData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = data.wide ? 320.0 : 154.0;
    final height = data.wide ? 92.0 : 170.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF73E8DF) : const Color(0xFFF3F8F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? const Color(0xFF5ED8CF) : const Color(0xFFE4EEEB),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: selected
                  ? const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Color(0xFF123C3A),
                    )
                  : const SizedBox(height: 18),
            ),
            Text(
              data.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF243234),
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.subtitle,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: Color(0xFF6C7A7B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
