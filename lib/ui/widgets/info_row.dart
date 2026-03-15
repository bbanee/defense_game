import 'package:flutter/material.dart';

class AppInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const AppInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF79A8FF), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFFF3F7FF),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFD9E7FF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
