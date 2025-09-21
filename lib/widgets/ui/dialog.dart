import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// 统一弹窗（基础 UI 组件）
class AppDialog {
  static Future<T?> confirm<T>(
    BuildContext context, {
    required String title,
    required String message,
    String? cancelLabel,
    String? okLabel,
    VoidCallback? onCancel,
    VoidCallback? onOk,
  }) {
    final l10n = AppLocalizations.of(context);
    cancelLabel ??= l10n.commonCancel;
    okLabel ??= l10n.commonConfirm;
    return _show<T>(
      context,
      title: title,
      message: message,
      actions: [
        (
          label: cancelLabel,
          onTap: () {
            Navigator.pop(context, false);
            if (onCancel != null) onCancel();
          },
          primary: false,
        ),
        (
          label: okLabel,
          onTap: () {
            Navigator.pop(context, true);
            if (onOk != null) onOk();
          },
          primary: true,
        ),
      ],
    );
  }

  static Future<T?> info<T>(
    BuildContext context, {
    required String title,
    required String message,
    String? okLabel,
    VoidCallback? onOk,
  }) {
    final l10n = AppLocalizations.of(context);
    okLabel ??= l10n.commonOk;
    return _show<T>(
      context,
      title: title,
      message: message,
      actions: [
        (
          label: okLabel,
          onTap: () {
            Navigator.pop(context, true);
            if (onOk != null) onOk();
          },
          primary: true,
        ),
      ],
    );
  }

  static Future<T?> error<T>(
    BuildContext context, {
    required String title,
    required String message,
    String? okLabel,
    VoidCallback? onOk,
  }) {
    final l10n = AppLocalizations.of(context);
    okLabel ??= l10n.commonOk;
    return _show<T>(
      context,
      title: title,
      message: message,
      actions: [
        (
          label: okLabel,
          onTap: () {
            Navigator.pop(context, true);
            if (onOk != null) onOk();
          },
          primary: true,
        ),
      ],
    );
  }

  static Future<T?> warning<T>(
    BuildContext context, {
    required String title,
    required String message,
    String? okLabel,
    VoidCallback? onOk,
  }) {
    final l10n = AppLocalizations.of(context);
    okLabel ??= l10n.commonOk;
    return _show<T>(
      context,
      title: title,
      message: message,
      actions: [
        (
          label: okLabel,
          onTap: () {
            Navigator.pop(context, true);
            if (onOk != null) onOk();
          },
          primary: true,
        ),
      ],
    );
  }

  static Future<T?> _show<T>(
    BuildContext context, {
    required String title,
    required String message,
    List<({String label, VoidCallback onTap, bool primary})>? actions,
  }) {
    final l10n = AppLocalizations.of(context);
    actions ??= [
      (label: l10n.commonCancel, onTap: () => Navigator.pop(context), primary: false),
      (label: l10n.commonConfirm, onTap: () => Navigator.pop(context), primary: true),
    ];


    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    textAlign: TextAlign.left,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final a in actions!) ...[
                    if (!a.primary)
                      Builder(builder: (context) {
                        final primary = Theme.of(ctx).colorScheme.primary;
                        return OutlinedButton(
                          onPressed: a.onTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primary,
                            side: BorderSide(color: primary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(a.label),
                        );
                      })
                    else
                      FilledButton(
                          onPressed: a.onTap,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(a.label)),
                    const SizedBox(width: 12),
                  ]
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

}
