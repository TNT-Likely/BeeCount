import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Profile-only contrast treatment. Other app/brand BeeIcon users stay unchanged.
class MineDefaultAvatar extends StatelessWidget {
  const MineDefaultAvatar({super.key});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
      Theme.of(context).brightness == Brightness.dark
          ? 'assets/images/bee_profile_dark.svg'
          : 'assets/bee.svg',
      width: 48,
      height: 48,
      theme: SvgTheme(currentColor: Theme.of(context).colorScheme.primary));
}
