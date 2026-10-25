import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

@immutable
class BeeSupportAction {
  const BeeSupportAction(
      {required this.title,
      this.subtitle,
      this.leading,
      this.trailing,
      this.onTap,
      this.key});
  final String title;
  final String? subtitle;
  final Widget? leading, trailing;
  final VoidCallback? onTap;
  final Key? key;
}

class BeeSupportActions extends StatelessWidget {
  const BeeSupportActions({super.key, required this.actions});
  final List<BeeSupportAction> actions;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < actions.length; i++)
          BeeMenuRow(
              key: actions[i].key,
              title: actions[i].title,
              subtitle: actions[i].subtitle,
              leading: actions[i].leading,
              trailing: actions[i].trailing,
              onTap: actions[i].onTap,
              divider: i < actions.length - 1),
      ]));
}

class BeeSupportText extends StatelessWidget {
  const BeeSupportText(
      {super.key,
      required this.title,
      this.description,
      this.icon,
      this.children = const []});
  final String title;
  final String? description;
  final Widget? icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null) ...[icon!, const SizedBox(width: 10)],
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)))
        ]),
        if (description != null) ...[
          const SizedBox(height: 10),
          Text(description!,
              style: TextStyle(
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant))
        ],
        ...children,
      ]));
}

class BeeSupportBrand extends StatelessWidget {
  const BeeSupportBrand(
      {super.key,
      required this.logo,
      required this.title,
      required this.version,
      required this.onStory,
      required this.socials});
  final Widget logo;
  final String title, version;
  final VoidCallback onStory;
  final List<BeeSupportAction> socials;
  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(children: [
              logo,
              const SizedBox(height: 12),
              TextButton.icon(
                  key: const ValueKey('support-story'),
                  onPressed: onStory,
                  icon: const BeeLineIcon('BookOpen', size: 18),
                  label: Text(title,
                      style: const TextStyle(
                          fontSize: 23, fontWeight: FontWeight.w600))),
              Text(version,
                  style: TextStyle(color: Theme.of(context).hintColor)),
            ])),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 10,
            children: [
              for (final action in socials)
                SizedBox(
                    width: 64,
                    child: InkWell(
                        key: action.key,
                        onTap: action.onTap,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Column(children: [
                              SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: Center(child: action.leading)),
                              const SizedBox(height: 5),
                              Text(action.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11))
                            ]))))
            ]),
      ]);
}

/// The host supplies the actual platform WebView and original URL/navigation.
class BeeSupportDocument extends StatelessWidget {
  const BeeSupportDocument(
      {super.key,
      required this.view,
      required this.progress,
      required this.failed,
      required this.failureLabel,
      required this.retryLabel,
      required this.browserLabel,
      required this.onRetry,
      required this.onBrowser});
  final Widget view;
  final int progress;
  final bool failed;
  final String failureLabel, retryLabel, browserLabel;
  final VoidCallback onRetry, onBrowser;
  @override
  Widget build(BuildContext context) => Stack(children: [
        if (!failed)
          Positioned.fill(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(17, 8, 17, 16),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(22), child: view)))
        else
          Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(17),
                  child: BeeSupportText(
                      title: failureLabel,
                      icon: const BeeLineIcon('WifiOff'),
                      children: [
                        const SizedBox(height: 16),
                        BeeButton(
                            key: const ValueKey('support-document-retry'),
                            label: retryLabel,
                            onPressed: onRetry),
                        const SizedBox(height: 8),
                        BeeButton(
                            key: const ValueKey('support-document-browser'),
                            label: browserLabel,
                            kind: BeeButtonKind.quiet,
                            onPressed: onBrowser)
                      ]))),
        if (!failed && progress < 100)
          Positioned(
              top: 0,
              left: 17,
              right: 17,
              child:
                  LinearProgressIndicator(value: progress / 100, minHeight: 2)),
      ]);
}

class BeeSupportShortcut extends StatelessWidget {
  const BeeSupportShortcut(
      {super.key,
      required this.title,
      required this.description,
      required this.url,
      required this.icon,
      required this.onCopy});
  final String title, description, url;
  final Widget icon;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 32, child: icon),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: TextStyle(
                          fontSize: 12, color: Theme.of(context).hintColor)),
                  const SizedBox(height: 5),
                  Text(url,
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary))
                ])),
            const SizedBox(width: 6),
            const BeeLineIcon('Copy', size: 18)
          ])));
}

@immutable
class BeeDonationOption {
  const BeeDonationOption(
      {required this.id,
      required this.title,
      required this.price,
      required this.emoji});
  final String id, title, price, emoji;
}

class BeeDonationOptions extends StatelessWidget {
  const BeeDonationOptions(
      {super.key,
      required this.options,
      required this.onDonate,
      required this.loading,
      required this.emptyLabel,
      required this.busyId});
  final List<BeeDonationOption> options;
  final ValueChanged<String> onDonate;
  final bool loading;
  final String emptyLabel;
  final String? busyId;
  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (options.isEmpty) return BeeEmptyState(title: emptyLabel);
    return BeeSupportActions(actions: [
      for (final option in options)
        BeeSupportAction(
            key: ValueKey('support-donate-${option.id}'),
            title: option.title,
            leading: Text(option.emoji, style: const TextStyle(fontSize: 23)),
            trailing: busyId == option.id
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: Text(option.price,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600))),
            onTap: busyId == null ? () => onDonate(option.id) : null)
    ]);
  }
}
