import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controlled two-factor challenge. Verification, draft validation and navigation
/// belong to the App; this view only renders supplied state and emits callbacks.
class BeeTwoFactorChallengeDialog extends StatelessWidget {
  const BeeTwoFactorChallengeDialog(
      {super.key,
      required this.title,
      required this.email,
      required this.method,
      required this.totpLabel,
      required this.recoveryLabel,
      required this.totpHint,
      required this.recoveryHint,
      required this.cancelLabel,
      required this.verifyLabel,
      required this.controller,
      required this.hasRecovery,
      required this.verifying,
      required this.canSubmit,
      required this.onMethodChanged,
      required this.onCodeChanged,
      required this.onSubmit,
      required this.onCancel,
      this.errorMessage,
      this.primaryColor,
      this.foregroundColor,
      this.secondaryColor,
      this.hintColor});
  final String title,
      email,
      method,
      totpLabel,
      recoveryLabel,
      totpHint,
      recoveryHint,
      cancelLabel,
      verifyLabel;
  final TextEditingController controller;
  final bool hasRecovery, verifying, canSubmit;
  final String? errorMessage;
  final Color? primaryColor, foregroundColor, secondaryColor, hintColor;
  final ValueChanged<String> onMethodChanged, onCodeChanged;
  final VoidCallback onSubmit, onCancel;
  @override
  Widget build(BuildContext context) {
    final hintStyle = TextStyle(
        color: hintColor ?? Theme.of(context).hintColor,
        fontSize: 14,
        letterSpacing: 0,
        fontWeight: FontWeight.normal);
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email,
              style: TextStyle(
                color: secondaryColor ??
                    Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            if (hasRecovery)
              Row(
                children: [
                  Expanded(
                    child: _TwoFactorMethodTab(
                      label: totpLabel,
                      selected: method == 'totp',
                      onTap: verifying ? null : () => onMethodChanged('totp'),
                    ),
                  ),
                  Expanded(
                    child: _TwoFactorMethodTab(
                      label: recoveryLabel,
                      selected: method == 'recovery_code',
                      onTap: verifying
                          ? null
                          : () => onMethodChanged('recovery_code'),
                    ),
                  ),
                ],
              ),
            if (hasRecovery) const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              enabled: !verifying,
              textAlign: TextAlign.center,
              keyboardType:
                  method == 'totp' ? TextInputType.number : TextInputType.text,
              inputFormatters: method == 'totp'
                  ? [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ]
                  : [LengthLimitingTextInputFormatter(20)],
              style: TextStyle(
                fontSize: method == 'totp' ? 22 : 18,
                letterSpacing: method == 'totp' ? 6 : 1.5,
                fontFamily: 'monospace',
                color:
                    foregroundColor ?? Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: method == 'totp' ? totpHint : recoveryHint,
                hintStyle: hintStyle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              onChanged: onCodeChanged,
              onSubmitted: (_) {
                if (canSubmit) onSubmit();
              },
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withValues(
                        alpha: 0.08,
                      ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline,
                        size: 16, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: verifying ? null : onCancel,
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
                primaryColor ?? Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: canSubmit ? onSubmit : null,
          child: verifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(verifyLabel),
        ),
      ],
    );
  }
}

class _TwoFactorMethodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _TwoFactorMethodTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
