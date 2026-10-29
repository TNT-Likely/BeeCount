import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/security/app_lock_service.dart';
import '../../shared/scaffold/widgets/page_scaffold.dart';

/// Original current-PIN gate before disabling the lock; no preference writes.
class PinVerificationPage extends StatefulWidget {
  const PinVerificationPage({super.key});
  @override
  State<PinVerificationPage> createState() => _PinVerificationPageState();
}

class _PinVerificationPageState extends State<PinVerificationPage> {
  String pin = '';
  bool invalid = false, busy = false;
  Future<void> digit(String value) async {
    if (busy || invalid || pin.length >= 4) return;
    setState(() => pin += value);
    if (pin.length != 4) return;
    setState(() => busy = true);
    final valid = await AppLockService.verifyPin(pin);
    if (!mounted) return;
    if (valid) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => invalid = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        pin = '';
        invalid = false;
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.appLockVerifyPin, leading: const BackButton()),
      Expanded(
          child: SafeArea(
              top: false,
              child: BeeSecurityPanel(
                  title: l.appLockVerifyCurrentPin,
                  subtitle: l.appLockDesc,
                  inputBuilder: (compact) => BeePinPad(
                      length: 4,
                      filled: pin.length,
                      invalid: invalid,
                      enabled: !busy && !invalid,
                      cardKeys: true,
                      compact: compact,
                      deleteLabel: l.commonDelete,
                      onDigit: digit,
                      onDelete: () {
                        if (!busy && !invalid && pin.isNotEmpty) {
                          setState(
                              () => pin = pin.substring(0, pin.length - 1));
                        }
                      }))))
    ]));
  }
}
