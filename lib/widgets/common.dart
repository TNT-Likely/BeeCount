import 'package:flutter/material.dart';
import '../styles/design.dart';
import '../styles/colors.dart';

// 金额格式：最多保留2位小数，移除多余0和末尾小数点
String formatMoneyCompact(double v,
    {int maxDecimals = 2, bool signed = false}) {
  final sign = signed ? (v < 0 ? '-' : '+') : '';
  String s = v.abs().toStringAsFixed(maxDecimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return '$sign$s';
}

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
  final Widget? leadingWidget;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? trailing;
  const AppListTile(
      {super.key,
      required this.leading,
      this.leadingWidget,
      required this.title,
      this.subtitle,
      this.onTap,
      this.enabled = true,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontSize: 15, color: BeeColors.primaryText);
    final subStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: BeeColors.black54);
    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          leadingWidget ??
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  leading,
                  color: Theme.of(context).colorScheme.primary,
                ),
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
          if (trailing != null)
            trailing!
          else if (enabled)
            const Icon(Icons.chevron_right, color: Colors.black38),
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: tile,
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
                  ?.copyWith(color: BeeColors.primaryText));
    final s = formatMoneyCompact(value, maxDecimals: decimals, signed: signed);
    return Text(
      s,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: style ??
          Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: BeeColors.primaryText),
    );
  }

  // 旧格式化函数已移除，统一使用 formatMoneyCompact
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
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

    String fmt(double v) => v == 0 ? '' : formatMoneyCompact(v, maxDecimals: 2);
    final grey = BeeColors.black54;
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

/// 小胶囊标签
class InfoTag extends StatelessWidget {
  final String text;
  const InfoTag(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
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

/// 统一弹窗（简单版）
class AppDialog {
  static Future<T?> show<T>(BuildContext context,
      {required String title,
      required String message,
      List<({String label, VoidCallback onTap, bool primary})>? actions}) {
    actions ??= [
      (label: '取消', onTap: () => Navigator.pop(context), primary: false),
      (label: '确定', onTap: () => Navigator.pop(context), primary: true),
    ];
    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final a in actions!) ...[
                  if (!a.primary)
                    Builder(builder: (context) {
                      final primary = Theme.of(ctx).colorScheme.primary;
                      return OutlinedButton(
                        onPressed: a.onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(color: primary),
                        ),
                        child: Text(a.label),
                      );
                    })
                  else
                    FilledButton(onPressed: a.onTap, child: Text(a.label)),
                  const SizedBox(width: 12),
                ]
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// 轻量 Toast，不占据布局空间，不会顶起 FAB
void showToast(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 2)}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(
    builder: (ctx) => IgnorePointer(
      ignoring: true,
      child: Positioned.fill(
        child: SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(duration, () {
    entry.remove();
  });
}
