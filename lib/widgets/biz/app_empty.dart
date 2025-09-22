import 'package:beecount/widgets/biz/bee_icon.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class AppEmpty extends StatelessWidget {
  final String? text;
  final String? subtext;
  const AppEmpty({super.key, this.text, this.subtext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final bg = primary.withValues(alpha: 0.08);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: BeeIcon(
                color: primary,
                size: 52,
                // child: SvgPicture.asset(
                //   'assets/title-logo.svg',
                //   width: 52,
                //   height: 52,
                //   color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(text ?? AppLocalizations.of(context).commonEmpty,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            if (subtext != null) ...[
              const SizedBox(height: 6),
              Text(subtext!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
