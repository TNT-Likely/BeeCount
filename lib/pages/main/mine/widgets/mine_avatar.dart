import 'package:flutter/material.dart';
import '../../../shared/branding/bee_artwork.dart';

/// Use the same original bee and dark-mode backing as the other brand entries.
class MineDefaultAvatar extends StatelessWidget {
  const MineDefaultAvatar({super.key});

  @override
  Widget build(BuildContext context) =>
      BeeIcon(color: Theme.of(context).colorScheme.primary, size: 48);
}
