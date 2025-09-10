import 'package:flutter/material.dart';

/// 统一弹窗（基础 UI 组件）
class AppDialog {
  static Future<T?> confirm<T>(
    BuildContext context, {
    required String title,
    required String message,
    String cancelLabel = '取消',
    String okLabel = '确定',
    VoidCallback? onCancel,
    VoidCallback? onOk,
  }) {
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
    String okLabel = '知道了',
    VoidCallback? onOk,
  }) {
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
    String okLabel = '知道了',
    VoidCallback? onOk,
  }) {
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
    String okLabel = '知道了',
    VoidCallback? onOk,
  }) {
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
    actions ??= [
      (label: '取消', onTap: () => Navigator.pop(context), primary: false),
      (label: '确定', onTap: () => Navigator.pop(context), primary: true),
    ];
    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.left,
              style: Theme.of(ctx).textTheme.bodyMedium,
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
    );
  }
}
