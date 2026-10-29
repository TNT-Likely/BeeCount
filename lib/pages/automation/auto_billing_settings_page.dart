import 'package:beecount_business_ui/auto_billing.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'android/bindings/auto_billing_actions.dart';
import 'ios_auto_billing_page.dart';

/// The existing platform branch is supplied by the App binding.
class AutoBillingSettingsPage extends ConsumerWidget {
  const AutoBillingSettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(autoBillingPlatformProvider) == AutoBillingPlatform.ios
          ? const IOSAutoBillingPage()
          : const AndroidAutoBillingPage();
}

class AndroidAutoBillingPage extends ConsumerStatefulWidget {
  const AndroidAutoBillingPage({super.key});
  @override
  ConsumerState<AndroidAutoBillingPage> createState() =>
      _AndroidAutoBillingPageState();
}

class _AndroidAutoBillingPageState extends ConsumerState<AndroidAutoBillingPage>
    with WidgetsBindingObserver {
  late AutoBillingAndroidActions _actions;
  bool _isMonitorEnabled = false, _isBatteryOptimizationIgnored = false;
  bool _isLoading = true,
      _initialized = false,
      _changing = false,
      _checkingBattery = false;
  Object? _loadError, _batteryError;
  int _statusRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _actions = ref.read(autoBillingAndroidActionsFactoryProvider)(
          ProviderScope.containerOf(context));
      _initialized = true;
      _loadMonitorStatus();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_changing && _initialized) {
      _loadMonitorStatus();
    }
  }

  Future<void> _loadMonitorStatus() async {
    final request = ++_statusRequest;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final enabled = await _actions.isEnabled();
      Map<String, dynamic>? battery;
      Object? batteryError;
      try {
        battery = await _actions.batteryInfo();
      } catch (error) {
        batteryError = error;
      }
      if (!mounted || request != _statusRequest) return;
      setState(() {
        _isMonitorEnabled = enabled;
        _isBatteryOptimizationIgnored = battery?['isIgnoring'] == true;
        _batteryError = batteryError;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || request != _statusRequest) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMonitor(bool value) async {
    if (_changing || _isLoading || _loadError != null) return;
    final l = AppLocalizations.of(context);
    setState(() => _changing = true);
    try {
      if (value) {
        final granted = await _actions.requestScreenshotPermission();
        if (!mounted) return;
        if (!granted) {
          showBeeToast(context, l.photosPermissionRequired);
          return;
        }
        await _actions.enable();
      } else {
        await _actions.disable();
      }
      if (!mounted) return;
      ++_statusRequest;
      setState(() => _isMonitorEnabled = value);
      showBeeToast(context, value ? l.enableSuccess : l.disableSuccess);
    } catch (error) {
      if (mounted) {
        showBeeToast(
            context, '${value ? l.enableFailed : l.disableFailed}: $error',
            duration: const Duration(seconds: 3));
      }
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Future<void> _checkBattery() async {
    if (_checkingBattery || _changing) return;
    final l = AppLocalizations.of(context);
    setState(() => _checkingBattery = true);
    try {
      final info = await _actions.batteryInfo();
      if (!mounted) return;
      final ignored = info['isIgnoring'] == true;
      final request = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => BeeAutoBillingBatteryDialog(
                title: l.reminderBatteryStatus,
                deviceLines: [
                  l.reminderManufacturer(
                      (info['manufacturer'] ?? 'Unknown').toString()),
                  l.reminderModel((info['model'] ?? 'Unknown').toString()),
                  l.reminderAndroidVersion(
                      (info['androidVersion'] ?? 'Unknown').toString())
                ],
                status: ignored
                    ? l.reminderBatteryIgnored
                    : l.reminderBatteryNotIgnored,
                warning: ignored ? '' : l.autoBillingBatteryWarning,
                settingsLabel: l.commonSettings,
                confirmLabel: l.commonConfirm,
                onSettings: !ignored && info['canRequest'] == true
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                onConfirm: () => Navigator.pop(dialogContext, false),
              ));
      if (!mounted) return;
      if (request == true) await _actions.requestIgnoreBatteryOptimizations();
      if (mounted) await _loadMonitorStatus();
    } catch (error) {
      if (mounted) showBeeToast(context, '${l.commonError}: $error');
    } finally {
      if (mounted) setState(() => _checkingBattery = false);
    }
  }

  @override
  void dispose() {
    ++_statusRequest;
    WidgetsBinding.instance.removeObserver(this);
    if (_initialized) _actions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
        backgroundColor: BeeCardTheme.of(context).canvas,
        body: Column(children: [
          BeePageHeader(
              title: l.autoScreenshotBillingTitle,
              leading: BeeIconButton(
                  label: l.commonBack,
                  icon: const BeeLineIcon('ChevronLeft', size: 22),
                  onPressed: () => Navigator.maybePop(context))),
          Expanded(
              child: BeePageBody(children: [
            BeeAutoBillingInfoCard(
                title: l.featureDescription,
                description: l.featureDescriptionContent),
            if (_loadError != null)
              BeeSurface(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    BeeStatus(label: l.commonError, tone: BeeTone.error),
                    const SizedBox(height: 10),
                    TextButton(
                        key: const ValueKey('auto-billing-retry'),
                        onPressed: _loadMonitorStatus,
                        child: Text(l.helpCenterRetry))
                  ])),
            BeeAutoBillingMonitorCard(
                title: l.autoBilling,
                status: _isLoading
                    ? ''
                    : _isMonitorEnabled
                        ? l.enabled
                        : l.disabled,
                enabled: _isMonitorEnabled,
                busy: _isLoading || _changing,
                onChanged: _loadError == null ? _toggleMonitor : null),
            BeeAutoBillingBatteryCard(
                title: l.autoBillingBatteryTitle,
                status: _batteryError != null
                    ? l.commonError
                    : _isLoading
                        ? ''
                        : _isBatteryOptimizationIgnored
                            ? l.reminderBatteryIgnored
                            : l.reminderBatteryNotIgnored,
                healthy: _batteryError == null && _isBatteryOptimizationIgnored,
                loading: _isLoading),
            BeeAutoBillingActionCard(
                title: l.autoBillingBatteryGuideTitle,
                description: l.autoBillingBatteryDesc,
                actionLabel: l.autoBillingCheckBattery,
                icon: 'BatteryCharging',
                actionKey: const ValueKey('auto-billing-check-battery'),
                busy: _checkingBattery,
                onAction: _changing ? null : _checkBattery),
          ])),
        ]));
  }
}
