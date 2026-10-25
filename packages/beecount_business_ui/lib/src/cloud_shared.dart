import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Content-only card used by shared cloud flows; no provider or network access.
class BeeCloudSharedCard extends StatelessWidget {
  const BeeCloudSharedCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) =>
      BeeSurface(padding: padding, child: child);
}

class BeeCloudSharedAction extends StatelessWidget {
  const BeeCloudSharedAction(
      {super.key,
      required this.title,
      required this.icon,
      this.subtitle,
      this.onTap,
      this.destructive = false,
      this.busy = false});
  final String title;
  final String? subtitle;
  final Widget icon;
  final VoidCallback? onTap;
  final bool destructive, busy;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: icon,
        title: Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    destructive ? beeToneColor(context, BeeTone.error) : null)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!,
                style: const TextStyle(fontSize: 12, height: 1.5)),
        trailing: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : onTap == null
                ? null
                : const BeeLineIcon('ChevronRight', size: 19),
        onTap: busy ? null : onTap,
      ));
}

class BeeCloudSharedInviteForm extends StatelessWidget {
  const BeeCloudSharedInviteForm(
      {super.key,
      required this.roleLabel,
      required this.role,
      required this.expiryLabel,
      required this.expiryOptions,
      required this.selectedHours,
      required this.onExpiry,
      required this.generateLabel,
      required this.onGenerate,
      required this.warning,
      this.busy = false,
      this.error});
  final String roleLabel, role, expiryLabel, generateLabel, warning;
  final Map<int, String> expiryOptions;
  final int selectedHours;
  final ValueChanged<int> onExpiry;
  final VoidCallback? onGenerate;
  final bool busy;
  final String? error;
  @override
  Widget build(BuildContext context) => BeeCloudSharedCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(roleLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 9),
        Align(alignment: Alignment.centerLeft, child: BeeStatus(label: role)),
        const SizedBox(height: 22),
        Text(expiryLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 9),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final entry in expiryOptions.entries)
            BeeChoiceChip(
                label: entry.value,
                compact: true,
                selected: selectedHours == entry.key,
                onSelected: busy
                    ? null
                    : (selected) {
                        if (selected) onExpiry(entry.key);
                      })
        ]),
        if (error != null) ...[
          const SizedBox(height: 12),
          BeeStatus(label: error!, tone: BeeTone.error)
        ],
        const SizedBox(height: 22),
        BeeButton(
            label: generateLabel,
            icon: const BeeLineIcon('UserPlus', size: 19),
            loading: busy,
            onPressed: busy ? null : onGenerate),
        const SizedBox(height: 18),
        Text(warning,
            style: TextStyle(
                fontSize: 12, height: 1.6, color: Theme.of(context).hintColor)),
      ]));
}

class BeeCloudSharedInviteCode extends StatelessWidget {
  const BeeCloudSharedInviteCode(
      {super.key,
      required this.code,
      required this.expiry,
      required this.copyCodeLabel,
      required this.shareLabel,
      required this.copyLinkLabel,
      required this.instruction,
      required this.anotherLabel,
      required this.onCopyCode,
      required this.onShare,
      required this.onCopyLink,
      required this.onAnother});
  final String code,
      expiry,
      copyCodeLabel,
      shareLabel,
      copyLinkLabel,
      instruction,
      anotherLabel;
  final VoidCallback onCopyCode, onShare, onCopyLink, onAnother;
  @override
  Widget build(BuildContext context) => BeeCloudSharedCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        Center(
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SelectableText(code,
                    style: const TextStyle(
                        fontSize: 36,
                        fontFamily: 'monospace',
                        letterSpacing: 6,
                        fontWeight: FontWeight.w700)))),
        const SizedBox(height: 12),
        Text(expiry,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 26),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              BeeButton(
                  label: copyCodeLabel,
                  kind: BeeButtonKind.secondary,
                  icon: const BeeLineIcon('Copy', size: 17),
                  onPressed: onCopyCode),
              BeeButton(
                  label: shareLabel,
                  icon: const BeeLineIcon('Share2', size: 17),
                  onPressed: onShare)
            ]),
        const SizedBox(height: 10),
        BeeButton(
            label: copyLinkLabel,
            kind: BeeButtonKind.secondary,
            onPressed: onCopyLink),
        const SizedBox(height: 22),
        Text(instruction,
            style: TextStyle(
                fontSize: 12, height: 1.6, color: Theme.of(context).hintColor)),
        const SizedBox(height: 12),
        BeeButton(
            label: anotherLabel,
            kind: BeeButtonKind.quiet,
            onPressed: onAnother),
      ]));
}

/// Avatar is supplied by the App. This component never resolves remote URLs.
class BeeCloudSharedMemberRow extends StatelessWidget {
  const BeeCloudSharedMemberRow(
      {super.key,
      required this.avatar,
      required this.name,
      required this.email,
      required this.role,
      this.selfLabel,
      this.removeLabel,
      this.onRemove,
      this.busy = false});
  final Widget avatar;
  final String name, email, role;
  final String? selfLabel, removeLabel;
  final VoidCallback? onRemove;
  final bool busy;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        avatar,
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (selfLabel != null)
                  Text('($selfLabel)',
                      style: TextStyle(
                          fontSize: 11, color: Theme.of(context).hintColor))
              ]),
          const SizedBox(height: 5),
          Text(email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 11, color: Theme.of(context).hintColor))
        ])),
        const SizedBox(width: 8),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: BeeCardTheme.of(context).soft,
                borderRadius: BorderRadius.circular(8)),
            child: Text(role,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600))),
        if (onRemove != null)
          BeeIconButton(
              label: removeLabel ?? '',
              icon: BeeLineIcon('UserMinus',
                  size: 19, color: beeToneColor(context, BeeTone.error)),
              onPressed: busy ? null : onRemove),
      ]));
}

class BeeCloudSharedHealthRow extends StatelessWidget {
  const BeeCloudSharedHealthRow(
      {super.key,
      required this.label,
      required this.value,
      this.warning = false});
  final String label, value;
  final bool warning;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor))),
        const SizedBox(width: 16),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: warning ? FontWeight.w600 : FontWeight.w400,
                    color: warning
                        ? beeToneColor(context, BeeTone.warning)
                        : null))),
      ]));
}

class BeeCloudSharedJoinForm extends StatelessWidget {
  const BeeCloudSharedJoinForm(
      {super.key,
      required this.title,
      required this.hint,
      required this.input,
      required this.previewLabel,
      required this.onPreview,
      this.busy = false});
  final String title, hint, previewLabel;
  final Widget input;
  final VoidCallback? onPreview;
  final bool busy;
  @override
  Widget build(BuildContext context) => BeeCloudSharedCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(hint,
            style: TextStyle(
                fontSize: 12, height: 1.6, color: Theme.of(context).hintColor)),
        const SizedBox(height: 22),
        input,
        const SizedBox(height: 22),
        BeeButton(
            label: previewLabel,
            loading: busy,
            onPressed: busy ? null : onPreview),
      ]));
}

class BeeCloudSharedJoinPreview extends StatelessWidget {
  const BeeCloudSharedJoinPreview(
      {super.key,
      required this.inviter,
      required this.ledger,
      required this.role,
      required this.expiry,
      required this.expiryDate,
      required this.cancelLabel,
      required this.acceptLabel,
      required this.onCancel,
      required this.onAccept,
      this.error,
      this.busy = false});
  final String inviter,
      ledger,
      role,
      expiry,
      expiryDate,
      cancelLabel,
      acceptLabel;
  final String? error;
  final VoidCallback? onCancel, onAccept;
  final bool busy;
  @override
  Widget build(BuildContext context) => BeeCloudSharedCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Center(
            child: CircleAvatar(
                radius: 27, child: BeeLineIcon('Users', size: 26))),
        const SizedBox(height: 16),
        Text(inviter,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 8),
        Text(ledger,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Center(child: BeeStatus(label: role)),
        const SizedBox(height: 10),
        Text(expiry,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        if (error != null) ...[
          const SizedBox(height: 12),
          BeeStatus(label: error!, tone: BeeTone.error)
        ],
        const SizedBox(height: 24),
        Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              BeeButton(
                  label: cancelLabel,
                  kind: BeeButtonKind.secondary,
                  onPressed: busy ? null : onCancel),
              BeeButton(
                  label: acceptLabel,
                  loading: busy,
                  onPressed: busy ? null : onAccept),
            ]),
        const SizedBox(height: 12),
        Text(expiryDate,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
      ]));
}

class BeeCloudSharedStatsSummary extends StatelessWidget {
  const BeeCloudSharedStatsSummary(
      {super.key,
      required this.incomeLabel,
      required this.expenseLabel,
      required this.income,
      required this.expense,
      required this.incomeColor,
      required this.expenseColor});
  final String incomeLabel, expenseLabel, income, expense;
  final Color incomeColor, expenseColor;
  @override
  Widget build(BuildContext context) => BeeCloudSharedCard(
          child: Row(children: [
        Expanded(
            child: _StatsTotal(
                label: incomeLabel, amount: income, color: incomeColor)),
        Container(
            width: 1, height: 38, color: BeeCardTheme.of(context).divider),
        Expanded(
            child: _StatsTotal(
                label: expenseLabel, amount: expense, color: expenseColor)),
      ]));
}

class _StatsTotal extends StatelessWidget {
  const _StatsTotal(
      {required this.label, required this.amount, required this.color});
  final String label, amount;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      child: Column(children: [
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
        const SizedBox(height: 7),
        Text(amount,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]));
}

class BeeCloudSharedStatsRow extends StatelessWidget {
  const BeeCloudSharedStatsRow(
      {super.key,
      required this.avatar,
      required this.name,
      required this.count,
      required this.income,
      required this.expense,
      required this.incomeColor,
      required this.expenseColor});
  final Widget avatar;
  final String name, count, income, expense;
  final Color incomeColor, expenseColor;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        avatar,
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(count,
              style:
                  TextStyle(fontSize: 11, color: Theme.of(context).hintColor))
        ])),
        const SizedBox(width: 10),
        Flexible(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(income,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: incomeColor,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(height: 4),
          Text(expense,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: expenseColor,
                  fontFeatures: const [FontFeature.tabularFigures()]))
        ])),
      ]));
}
