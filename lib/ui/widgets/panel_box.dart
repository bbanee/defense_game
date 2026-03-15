import 'package:flutter/material.dart';

class AppPanelBox extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const AppPanelBox({
    super.key,
    required this.child,
    required this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: child,
    );
  }
}
