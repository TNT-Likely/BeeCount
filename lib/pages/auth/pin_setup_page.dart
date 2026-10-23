import '../../presentation/v4/bindings/page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beecount_ui/beecount_ui.dart';
import '../../providers/security_providers.dart';
import '../../services/security/app_lock_service.dart';
import '../../widgets/ui/ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';

enum PinSetupMode { create, change }

class PinSetupPage extends ConsumerStatefulWidget {
  final PinSetupMode mode;

  const PinSetupPage({super.key, this.mode = PinSetupMode.create});

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  // 步骤：0=验证旧PIN（仅change模式）, 1=输入新PIN, 2=确认新PIN
  int _step = 0;
  String _pin = '';
  String _firstPin = '';
  bool _isError = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _step = widget.mode == PinSetupMode.change ? 0 : 1;
  }

  String get _title {
    final l10n = AppLocalizations.of(context);
    if (_step == 0) return l10n.appLockVerifyCurrentPin;
    if (_step == 1) return l10n.appLockSetNewPin;
    return l10n.appLockConfirmPin;
  }

  void _onNumberTap(String number) {
    if (_busy || _isError || _pin.length >= 4) return;
    setState(() {
      _isError = false;
      _pin += number;
    });
    if (_pin.length == 4) {
      _handlePinComplete();
    }
  }

  void _onDelete() {
    if (_busy || _isError || _pin.isEmpty) return;
    setState(() {
      _isError = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _handlePinComplete() async {
    if (_step == 0) {
      // 验证旧 PIN
      setState(() => _busy = true);
      final valid = await AppLockService.verifyPin(_pin);
      if (!mounted) return;
      setState(() => _busy = false);
      if (valid) {
        setState(() {
          _step = 1;
          _pin = '';
        });
      } else {
        _showError();
      }
    } else if (_step == 1) {
      // 记录第一次输入
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _step = 2;
      });
    } else {
      // 确认 PIN
      if (_pin == _firstPin) {
        setState(() => _busy = true);
        await AppLockService.setPin(_pin);
        if (!mounted) return;
        ref.read(appLockEnabledProvider.notifier).state = true;
        if (mounted) {
          showToast(context, AppLocalizations.of(context).appLockPinSetSuccess);
          Navigator.pop(context, true);
        }
      } else {
        _showError();
        // 重置到输入新 PIN 步骤
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() {
            _step = 1;
            _firstPin = '';
          });
        }
      }
    }
  }

  void _showError() {
    setState(() => _isError = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _pin = '';
          _isError = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
        backgroundColor: BeeCardTheme.of(context).canvas,
        body: Column(children: [
          BeePageHeader(
              title: widget.mode == PinSetupMode.create
                  ? l.appLockSetPin
                  : l.appLockChangePin,
              leading: const BackButton()),
          Expanded(
              child: SafeArea(
                  top: false,
                  child: BeeSecurityPanel(
                      title: _title,
                      subtitle: l.appLockDesc,
                      inputBuilder: (compact) => BeePinPad(
                          length: 4,
                          filled: _pin.length,
                          invalid: _isError,
                          enabled: !_busy && !_isError,
                          cardKeys: true,
                          compact: compact,
                          deleteLabel: l.commonDelete,
                          onDigit: (value) {
                            HapticFeedback.lightImpact();
                            _onNumberTap(value);
                          },
                          onDelete: _onDelete))))
        ]));
  }
}
