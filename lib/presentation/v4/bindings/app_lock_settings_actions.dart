import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/auth/pin_setup_page.dart';
import '../../../providers/security_providers.dart';
import '../../../services/security/app_lock_service.dart';
import '../../../widgets/ui/ui.dart' show showToast;
import 'pin_verification.dart';

List<(int, String)> appLockTimeoutOptions(AppLocalizations l) => [
      (0, l.appLockTimeoutImmediate),
      (60, l.appLockTimeout1Min),
      (300, l.appLockTimeout5Min),
      (900, l.appLockTimeout15Min),
    ];

/// Authentication and persisted preferences stay in the App, outside UI packages.
mixin AppLockSettingsActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool lockActionBusy = false;
  bool lockBiometricSupported = false;

  Future<void> checkLockBiometrics() async {
    final supported = await AppLockService.canUseBiometrics();
    if (mounted) setState(() => lockBiometricSupported = supported);
  }

  Future<void> lockAction(Future<void> Function() action) async {
    if (lockActionBusy) return;
    setState(() => lockActionBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => lockActionBusy = false);
    }
  }

  Future<void> toggleLock(bool enable) => lockAction(() async {
        if (enable) {
          // The existing setup page enables the lock only after confirmation.
          await Navigator.push<bool>(
              context, MaterialPageRoute(builder: (_) => const PinSetupPage()));
        } else {
          final message = AppLocalizations.of(context).appLockDisabled;
          final verified = await Navigator.push<bool>(context,
              MaterialPageRoute(builder: (_) => const PinVerificationPage()));
          if (verified != true || !mounted) return;
          await AppLockService.clearPin();
          if (!mounted) return;
          ref.read(appLockEnabledProvider.notifier).state = false;
          ref.read(appLockBiometricEnabledProvider.notifier).state = false;
          showToast(context, message);
        }
      });

  Future<void> changeLockPin() => lockAction(() async {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const PinSetupPage(mode: PinSetupMode.change)));
      });

  Future<void> toggleLockBiometric(bool enable) => lockAction(() async {
        if (enable) {
          final success = await AppLockService.authenticateWithBiometrics(
              reason: AppLocalizations.of(context).appLockBiometricReason);
          if (!success || !mounted) return;
        }
        await AppLockService.setBiometricEnabled(enable);
        if (mounted) {
          ref.read(appLockBiometricEnabledProvider.notifier).state = enable;
        }
      });

  String lockTimeoutLabel(int seconds) {
    for (final option in appLockTimeoutOptions(AppLocalizations.of(context))) {
      if (option.$1 == seconds) return option.$2;
    }
    return '${seconds}s';
  }

  Future<void> chooseLockTimeout() => lockAction(() async {
        final l = AppLocalizations.of(context),
            selected = ref.read(appLockTimeoutProvider);
        final seconds = await showBeeSheet<int>(context,
            title: l.appLockTimeout,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final option in appLockTimeoutOptions(l))
                BeeMenuRow(
                    title: option.$2,
                    selected: option.$1 == selected,
                    trailing: option.$1 == selected
                        ? BeeLineIcon('Check',
                            size: 18,
                            color: Theme.of(context).colorScheme.primary)
                        : const SizedBox(width: 18),
                    onTap: () => Navigator.pop(context, option.$1)),
            ])));
        if (seconds == null || !mounted) return;
        await AppLockService.setTimeoutSeconds(seconds);
        if (mounted) ref.read(appLockTimeoutProvider.notifier).state = seconds;
      });
}
