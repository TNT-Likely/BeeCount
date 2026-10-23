import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The same Lucide paths as the approved HTML design. Assets retain their ISC license.
class BeeLineIcon extends StatelessWidget {
  const BeeLineIcon(this.name, {super.key, this.size = 20, this.color});
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/$name.svg',
        package: 'beecount_ui',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(
            color ??
                IconTheme.of(context).color ??
                Theme.of(context).colorScheme.onSurface,
            BlendMode.srcIn),
      );
}
