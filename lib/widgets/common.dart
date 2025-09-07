import 'package:flutter/material.dart';
import '../styles/design.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SectionCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(AppDimens.p12)});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.p12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radius12),
        boxShadow: AppShadows.card,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppListTile extends StatelessWidget {
  final IconData leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const AppListTile(
      {super.key,
      required this.leading,
      required this.title,
      this.subtitle,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontSize: 15, color: Colors.black87);
    final subStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(leading, color: Colors.black87),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: subStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class AmountText extends StatelessWidget {
  final double value;
  final bool hide;
  final bool signed; // 是否显示正负号
  final int decimals;
  final TextStyle? style;
  const AmountText(
      {super.key,
      required this.value,
      this.hide = false,
      this.signed = true,
      this.decimals = 2,
      this.style});

  @override
  Widget build(BuildContext context) {
    if (hide)
      return Text('****',
          style: style ??
              Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.black87));
    final s = _format(value, signed: signed, decimals: decimals);
    return Text(
      s,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: style ??
          Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.black87),
    );
  }

  String _format(double v, {bool signed = true, int decimals = 2}) {
    final sign = signed ? (v < 0 ? '-' : '+') : '';
    final abs = v.abs();
    return '$sign${abs.toStringAsFixed(decimals)}';
  }
}
