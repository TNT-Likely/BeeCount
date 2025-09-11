import 'package:flutter/material.dart';
import '../../styles/colors.dart';

class InfoTag extends StatelessWidget {
  final String text;
  const InfoTag(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: BeeColors.black54),
      ),
    );
  }
}
