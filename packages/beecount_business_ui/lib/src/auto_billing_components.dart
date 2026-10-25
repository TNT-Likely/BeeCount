import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Read-only explanation. The host supplies platform-specific copy.
class BeeAutoBillingInfoCard extends StatelessWidget {
  const BeeAutoBillingInfoCard(
      {super.key,
      required this.title,
      required this.description,
      this.icon = 'Info'});
  final String title, description, icon;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading(context, icon, title),
        const SizedBox(height: 12),
        _copy(context, description),
      ]));
}

class BeeAutoBillingMonitorCard extends StatelessWidget {
  const BeeAutoBillingMonitorCard(
      {super.key,
      required this.title,
      required this.status,
      required this.enabled,
      required this.onChanged,
      this.busy = false});
  final String title, status;
  final bool enabled, busy;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: const EdgeInsets.all(6),
      child: BeeToggleRow(
          key: const ValueKey('auto-billing-monitor'),
          title: title,
          subtitle: status,
          leading: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const BeeLineIcon('ScanLine', size: 21),
          value: enabled,
          onChanged: busy ? null : onChanged));
}

class BeeAutoBillingBatteryCard extends StatelessWidget {
  const BeeAutoBillingBatteryCard(
      {super.key,
      required this.title,
      required this.status,
      required this.healthy,
      this.loading = false});
  final String title, status;
  final bool healthy, loading;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _visual(context, healthy ? 'BatteryFull' : 'BatteryWarning'),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(status,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).hintColor))
        ])),
        const SizedBox(width: 8),
        if (loading)
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
        else
          BeeLineIcon(healthy ? 'CircleCheck' : 'CircleAlert',
              size: 18,
              color:
                  healthy ? const Color(0xff23896d) : const Color(0xffbc802e)),
      ]));
}

class BeeAutoBillingActionCard extends StatelessWidget {
  const BeeAutoBillingActionCard(
      {super.key,
      required this.title,
      required this.description,
      required this.actionLabel,
      required this.onAction,
      this.icon = 'Download',
      this.busy = false,
      this.actionKey});
  final String title, description, actionLabel, icon;
  final VoidCallback? onAction;
  final bool busy;
  final Key? actionKey;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading(context, icon, title),
        const SizedBox(height: 12),
        _copy(context, description),
        const SizedBox(height: 16),
        BeeButton(
            key: actionKey,
            label: actionLabel,
            onPressed: busy ? null : onAction,
            loading: busy,
            icon: BeeLineIcon(icon, size: 18))
      ]));
}

class BeeAutoBillingTutorialCard extends StatelessWidget {
  const BeeAutoBillingTutorialCard(
      {super.key,
      required this.title,
      required this.description,
      required this.onOpen,
      this.busy = false});
  final String title, description;
  final VoidCallback? onOpen;
  final bool busy;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
          key: const ValueKey('auto-billing-tutorial'),
          onTap: busy ? null : onOpen,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _visual(context, 'CirclePlay'),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      _copy(context, description)
                    ])),
                const SizedBox(width: 8),
                if (busy)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const BeeLineIcon('ExternalLink', size: 17)
              ]))));
}

class BeeAutoBillingVersionNotice extends StatelessWidget {
  const BeeAutoBillingVersionNotice(
      {super.key, required this.title, required this.description});
  final String title, description;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BeeStatus(
            label: title,
            tone: BeeTone.warning,
            icon: const BeeLineIcon('TriangleAlert', size: 20)),
        const SizedBox(height: 10),
        _copy(context, description)
      ]));
}

/// The six-step fallback stays collapsed until the user chooses to open it.
class BeeAutoBillingManualGuide extends StatelessWidget {
  const BeeAutoBillingManualGuide(
      {super.key,
      required this.title,
      required this.description,
      required this.stepsTitle,
      required this.steps,
      required this.recommendation});
  final String title, description, stepsTitle, recommendation;
  final List<String> steps;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: BeeAccordion(
          key: const ValueKey('auto-billing-manual'),
          title: title,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _copy(context, description),
            const SizedBox(height: 16),
            Text(stepsTitle,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (var i = 0; i < steps.length; i++)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 25,
                            height: 25,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: BeeCardTheme.of(context).soft,
                                shape: BoxShape.circle),
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))),
                        const SizedBox(width: 10),
                        Expanded(child: _copy(context, steps[i]))
                      ])),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: BeeCardTheme.of(context).soft,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BeeLineIcon('CircleCheck', size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: _copy(context, recommendation))
                    ])),
          ])));
}

/// Device values and the decision to request an exemption belong to the host.
class BeeAutoBillingBatteryDialog extends StatelessWidget {
  const BeeAutoBillingBatteryDialog(
      {super.key,
      required this.title,
      required this.deviceLines,
      required this.status,
      required this.warning,
      required this.settingsLabel,
      required this.confirmLabel,
      required this.onConfirm,
      this.onSettings});
  final String title, status, warning, settingsLabel, confirmLabel;
  final List<String> deviceLines;
  final VoidCallback onConfirm;
  final VoidCallback? onSettings;
  @override
  Widget build(BuildContext context) => BeeDialog(
          title: Text(title),
          content:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final line in deviceLines)
              Padding(
                  padding: const EdgeInsets.only(bottom: 5), child: Text(line)),
            const SizedBox(height: 8),
            Text(status, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (warning.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(warning,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.error))
            ]
          ]),
          actions: [
            if (onSettings != null)
              TextButton(
                  key: const ValueKey('auto-billing-battery-settings'),
                  onPressed: onSettings,
                  child: Text(settingsLabel)),
            TextButton(
                key: const ValueKey('auto-billing-battery-confirm'),
                onPressed: onConfirm,
                child: Text(confirmLabel))
          ]);
}

Widget _heading(BuildContext context, String icon, String title) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      BeeLineIcon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, height: 1.5)))
    ]);
Widget _copy(BuildContext context, String value) => Text(value,
    style: TextStyle(
        fontSize: 13,
        height: 1.65,
        color: Theme.of(context).colorScheme.onSurfaceVariant));
Widget _visual(BuildContext context, String icon) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
        color: BeeCardTheme.of(context).soft,
        borderRadius: BorderRadius.circular(12)),
    child: Center(
        child: BeeLineIcon(icon,
            size: 21, color: Theme.of(context).colorScheme.primary)));
