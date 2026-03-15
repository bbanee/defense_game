import 'package:flutter/material.dart';

class AppPanelButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? borderColor;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final bool compact;

  const AppPanelButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.borderColor,
    this.foregroundColor,
    this.backgroundColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedForeground = foregroundColor ?? const Color(0xFF222222);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: borderColor ?? const Color(0xFF2D2D2D), width: 2),
        padding: compact
            ? const EdgeInsets.symmetric(vertical: 6, horizontal: 8)
            : const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        foregroundColor: resolvedForeground,
        backgroundColor: backgroundColor,
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: resolvedForeground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: resolvedForeground,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
