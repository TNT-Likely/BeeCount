import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/v4/bindings/app_lock_settings_actions.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
import '../../providers/security_providers.dart';

class AppLockSettingsPage extends ConsumerStatefulWidget {
  const AppLockSettingsPage({super.key});
  @override
  ConsumerState<AppLockSettingsPage> createState() =>
      _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends ConsumerState<AppLockSettingsPage>
    with AppLockSettingsActions<AppLockSettingsPage> {
  @override
  void initState() {
    super.initState();
    checkLockBiometrics();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        enabled = ref.watch(appLockEnabledProvider),
        biometric = ref.watch(appLockBiometricEnabledProvider),
        timeout = ref.watch(appLockTimeoutProvider);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.appLockTitle, leading: const BackButton()),
      Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(17, 12, 17, 24),
              children: [
            BeeSurface(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: BeeToggleRow(
                    title: l.appLockEnable,
                    subtitle: l.appLockEnableDesc,
                    leading: const BeeLineIcon('Lock'),
                    value: enabled,
                    onChanged: lockActionBusy ? null : toggleLock)),
            if (enabled) ...[
              const SizedBox(height: 12),
              BeeSurface(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: BeeMenuRow(
                      title: l.appLockChangePin,
                      leading: const BeeLineIcon('Keyboard'),
                      onTap: lockActionBusy ? null : changeLockPin)),
              const SizedBox(height: 12),
              BeeSurface(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: Column(children: [
                    if (lockBiometricSupported) ...[
                      BeeToggleRow(
                          title: l.appLockBiometric,
                          subtitle: l.appLockBiometricDesc,
                          leading: const BeeLineIcon('Fingerprint'),
                          value: biometric,
                          onChanged:
                              lockActionBusy ? null : toggleLockBiometric),
                      const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: BeeDivider(height: .6)),
                    ],
                    BeeMenuRow(
                        title: l.appLockTimeout,
                        subtitle: lockTimeoutLabel(timeout),
                        leading: const BeeLineIcon('Clock'),
                        onTap: lockActionBusy ? null : chooseLockTimeout),
                  ])),
            ],
          ])),
    ]));
  }
}
