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

/// 统一的明细行组件：左侧分类圆标，中间标题，右侧金额
class TransactionListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final double amount;
  final bool isExpense; // 决定正负号
  final bool hide;
  final VoidCallback? onTap;
  const TransactionListItem({
    super.key,
    required this.icon,
    required this.title,
    required this.amount,
    required this.isExpense,
    this.hide = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[200],
              child: Icon(icon,
                  color: Theme.of(context).colorScheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 15, color: Colors.black87),
              ),
            ),
            const SizedBox(width: 8),
            AmountText(
              value: isExpense ? -amount : amount,
              hide: hide,
              signed: true,
              decimals: 2,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 15, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

/// 统一的分组日期头：左侧日期+星期，右侧收入/支出（0 不显示）
class DaySectionHeader extends StatelessWidget {
  final String dateText; // yyyy-MM-dd
  final double income;
  final double expense;
  final bool hide;
  const DaySectionHeader({
    super.key,
    required this.dateText,
    required this.income,
    required this.expense,
    this.hide = false,
  });

  @override
  Widget build(BuildContext context) {
    String weekdayZh(String yyyyMMdd) {
      try {
        final dt = DateTime.parse(yyyyMMdd);
        const names = ['一', '二', '三', '四', '五', '六', '日'];
        return '星期${names[dt.weekday - 1]}';
      } catch (_) {
        return '';
      }
    }

    String fmt(double v) => v == 0 ? '' : v.toStringAsFixed(2);
    final grey = Colors.black54;
    final week = weekdayZh(dateText);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(dateText,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: grey, fontSize: 12)),
            if (week.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(week,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: grey, fontSize: 12)),
            ]
          ]),
          Row(children: [
            if (!hide && fmt(expense).isNotEmpty)
              Text('支出 ${fmt(expense)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: grey, fontSize: 12)),
            if (!hide && fmt(expense).isNotEmpty) const SizedBox(width: 12),
            if (!hide && fmt(income).isNotEmpty)
              Text('收入 ${fmt(income)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: grey, fontSize: 12)),
          ])
        ],
      ),
    );
  }
}

/// 统一空状态
class AppEmpty extends StatelessWidget {
  final String text;
  const AppEmpty({super.key, this.text = '暂无数据'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
