import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// A service choice. Configuration, authentication and diagnostics stay in App.
class BeeCloudServiceCard extends StatelessWidget {
  const BeeCloudServiceCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.selected,
      required this.onTap,
      this.disabled = false,
      this.configureLabel,
      this.guideLabel,
      this.onConfigure,
      this.onGuide});
  final String title, subtitle;
  final String? configureLabel, guideLabel;
  final Widget icon;
  final bool selected, disabled;
  final VoidCallback? onTap, onConfigure, onGuide;
  @override
  Widget build(BuildContext context) {
    final cards = BeeCardTheme.of(context);
    return Opacity(
        opacity: disabled ? .45 : 1,
        child: BeeSurface(
            padding: EdgeInsets.zero,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                      selected: selected,
                      button: true,
                      enabled: !disabled && onTap != null,
                      child: InkWell(
                          onTap: disabled ? null : onTap,
                          borderRadius: BorderRadius.circular(22),
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(children: [
                                Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                        color: cards.soft,
                                        borderRadius:
                                            BorderRadius.circular(13)),
                                    child: ExcludeSemantics(child: icon)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(title,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 5),
                                      Text(subtitle,
                                          style: TextStyle(
                                              fontSize: 12,
                                              height: 1.5,
                                              color:
                                                  Theme.of(context).hintColor)),
                                    ])),
                                const SizedBox(width: 8),
                                BeeLineIcon(
                                    selected ? 'CircleCheck' : 'ChevronRight',
                                    size: 21,
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).hintColor),
                              ])))),
                  if (!disabled && (onGuide != null || onConfigure != null))
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (onGuide != null)
                                BeeButton(
                                    label: guideLabel ?? title,
                                    icon: const BeeLineIcon('CircleHelp',
                                        size: 16),
                                    kind: BeeButtonKind.quiet,
                                    onPressed: onGuide),
                              if (onConfigure != null)
                                BeeButton(
                                    label: configureLabel ?? title,
                                    icon: const BeeLineIcon('Settings2',
                                        size: 16),
                                    kind: BeeButtonKind.secondary,
                                    onPressed: onConfigure),
                            ])),
                ])));
  }
}

class BeeCloudConnectionSummary extends StatelessWidget {
  const BeeCloudConnectionSummary(
      {super.key,
      required this.currentLabel,
      required this.service,
      required this.endpoint,
      required this.status,
      this.tone = BeeTone.neutral});
  final String currentLabel, service, endpoint, status;
  final BeeTone tone;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('$currentLabel: $service',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(endpoint,
            style: TextStyle(
                fontSize: 12, height: 1.5, color: Theme.of(context).hintColor)),
        const SizedBox(height: 12),
        BeeStatus(label: status, tone: tone),
      ]));
}

class BeeCloudBackupWarning extends StatelessWidget {
  const BeeCloudBackupWarning(
      {super.key, required this.title, required this.message, this.onTap});
  final String title, message;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                BeeLineIcon('TriangleAlert',
                    size: 22, color: beeToneColor(context, BeeTone.warning)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(message,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.55,
                              color: Theme.of(context).hintColor)),
                    ])),
                const SizedBox(width: 6),
                const BeeLineIcon('Info', size: 18),
              ]))));
}

class BeeCloudConfigurationDialog extends StatelessWidget {
  const BeeCloudConfigurationDialog(
      {super.key,
      required this.title,
      required this.fields,
      required this.cancelLabel,
      required this.saveLabel,
      required this.onCancel,
      required this.onSave});
  final String title, cancelLabel, saveLabel;
  final List<Widget> fields;
  final VoidCallback? onCancel, onSave;
  @override
  Widget build(BuildContext context) => BeeDialog(
          showClose: false,
          title: Text(title),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  fields[i],
                ]
              ]),
          actions: [
            BeeButton(
                label: cancelLabel,
                kind: BeeButtonKind.secondary,
                onPressed: onCancel),
            BeeButton(label: saveLabel, onPressed: onSave)
          ]);
}

/// Controlled login form; no provider, credential storage or authentication call.
class BeeCloudLoginForm extends StatelessWidget {
  const BeeCloudLoginForm(
      {super.key,
      required this.emailController,
      required this.passwordController,
      required this.emailLabel,
      required this.passwordLabel,
      required this.loginLabel,
      required this.rememberLabel,
      required this.rememberHint,
      required this.guideLabel,
      required this.rememberAccount,
      required this.showPassword,
      required this.onRemember,
      required this.onTogglePassword,
      required this.onLogin,
      required this.onGuide,
      this.busy = false,
      this.error});
  final TextEditingController emailController, passwordController;
  final String emailLabel,
      passwordLabel,
      loginLabel,
      rememberLabel,
      rememberHint,
      guideLabel;
  final bool rememberAccount, showPassword, busy;
  final String? error;
  final ValueChanged<bool>? onRemember;
  final VoidCallback? onTogglePassword, onLogin, onGuide;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BeeSurface(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              BeeField(
                  key: const ValueKey('cloud-login-email'),
                  label: emailLabel,
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              BeeField(
                  key: const ValueKey('cloud-login-password'),
                  label: passwordLabel,
                  controller: passwordController,
                  obscure: !showPassword,
                  suffixIcon: BeeIconButton(
                      label: passwordLabel,
                      onPressed: onTogglePassword,
                      icon: BeeLineIcon(showPassword ? 'EyeOff' : 'Eye',
                          size: 20))),
              const SizedBox(height: 8),
              BeeCheckTile(
                  label: rememberLabel,
                  subtitle: rememberHint,
                  value: rememberAccount,
                  onChanged: onRemember),
              if (error != null) ...[
                const SizedBox(height: 12),
                BeeStatus(label: error!, tone: BeeTone.error)
              ],
              const SizedBox(height: 16),
              BeeButton(label: loginLabel, loading: busy, onPressed: onLogin),
            ])),
        const SizedBox(height: 12),
        BeeButton(
            label: guideLabel, kind: BeeButtonKind.quiet, onPressed: onGuide),
      ]);
}

class BeeCloudConfiguredNotice extends StatelessWidget {
  const BeeCloudConfiguredNotice(
      {super.key,
      required this.title,
      required this.message,
      required this.backLabel,
      required this.onBack});
  final String title, message, backLabel;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const BeeLineIcon('CircleCheck', size: 36),
        const SizedBox(height: 18),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text(message,
            style: TextStyle(
                fontSize: 13, height: 1.6, color: Theme.of(context).hintColor)),
        const SizedBox(height: 22),
        BeeButton(label: backLabel, onPressed: onBack),
      ]));
}
