import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
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
    if (_pin.length >= 4) return;
    setState(() {
      _isError = false;
      _pin += number;
    });
    if (_pin.length == 4) {
      _handlePinComplete();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _isError = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _handlePinComplete() async {
    if (_step == 0) {
      // 验证旧 PIN
      final valid = await AppLockService.verifyPin(_pin);
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
        await AppLockService.setPin(_pin);
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
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: widget.mode == PinSetupMode.create
                ? AppLocalizations.of(context).appLockSetPin
                : AppLocalizations.of(context).appLockChangePin,
            showBack: true,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // 步骤提示
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 18.0.scaled(context, ref),
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                  SizedBox(height: 32.0.scaled(context, ref)),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: BeePinPad(
                            length: 4,
                            filled: _pin.length,
                            invalid: _isError,
                            deleteLabel:
                                AppLocalizations.of(context).commonDelete,
                            onDigit: (v) {
                              HapticFeedback.lightImpact();
                              _onNumberTap(v);
                            },
                            onDelete: _onDelete,
                          ))),
                  SizedBox(height: 32.0.scaled(context, ref)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
