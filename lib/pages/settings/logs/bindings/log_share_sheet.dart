import 'dart:convert';

import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../services/system/log_export_service.dart';
import '../../../../services/system/logger_service.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';

final logExportPlatformProvider =
    Provider<LogExportPlatform>((ref) => const LogExportPlatform());

Future<void> showLogShareSheet(BuildContext context, LoggerService logger) {
  final platform = ProviderScope.containerOf(context, listen: false)
      .read(logExportPlatformProvider);
  return showBeeSheet<void>(
    context,
    title: AppLocalizations.of(context).logShareTitle,
    child: _LogShareContent(logger: logger, platform: platform),
  );
}

class _LogShareContent extends StatefulWidget {
  const _LogShareContent({required this.logger, required this.platform});
  final LoggerService logger;
  final LogExportPlatform platform;

  @override
  State<_LogShareContent> createState() => _LogShareContentState();
}

class _LogShareContentState extends State<_LogShareContent> {
  late Future<LogExportSnapshot> _capture =
      LogExportSnapshot.capture(widget.logger);
  bool _busy = false;
  bool _shareFailed = false;
  bool _saveFailed = false;

  Rect _anchor(BuildContext buttonContext) {
    final button = buttonContext.findRenderObject() as RenderBox;
    final overlay = Navigator.of(buttonContext, rootNavigator: true)
        .overlay!
        .context
        .findRenderObject() as RenderBox;
    final visible = MatrixUtils.transformRect(
      button.getTransformTo(overlay),
      Offset.zero & button.size,
    ).intersect(Offset.zero & overlay.size);
    if (visible.isEmpty || !visible.isFinite) {
      throw StateError('Share button is outside the current window');
    }
    return visible;
  }

  Future<void> _share(BuildContext buttonContext, LogExportFile file) async {
    if (_busy) return;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    final subject = AppLocalizations.of(context).logShareSubject;
    setState(() => _busy = true);
    try {
      await widget.platform
          .share(file, origin: _anchor(buttonContext), subject: subject);
      // Cancellation and platforms without result reporting both finish the
      // interaction. Opening the chooser does not confirm delivery.
      if (mounted && route?.isCurrent == true) navigator.pop();
    } catch (_) {
      if (mounted) setState(() => _shareFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(LogExportFile file) async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    try {
      final saved =
          await widget.platform.save(file, dialogTitle: l.logShareSaveFile);
      if (saved && mounted && route?.isCurrent == true) {
        showBeeToast(context, l.commonSaved, tone: BeeTone.success);
        navigator.pop();
      }
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<LogExportSnapshot>(
      future: _capture,
      builder: (context, state) {
        if (state.hasError) {
          return BeeStatus(
            label: l.logShareLoadFailed,
            tone: BeeTone.error,
            action: TextButton(
              onPressed: () => setState(() {
                _capture = LogExportSnapshot.capture(widget.logger);
              }),
              child: Text(l.helpCenterRetry),
            ),
          );
        }
        final snapshot = state.data;
        if (snapshot == null) {
          return BeeStatus(label: l.logSharePreparing, tone: BeeTone.busy);
        }
        final file = snapshot.file;
        final send = Builder(
          builder: (buttonContext) => BeeButton(
            key: const ValueKey('log-share-send'),
            label: _shareFailed ? l.helpCenterRetry : l.logShareSend,
            icon: BeeLineIcon(_shareFailed ? 'RefreshCw' : 'Share2', size: 17),
            loading: _busy,
            onPressed:
                snapshot.count == 0 ? null : () => _share(buttonContext, file),
          ),
        );
        if (_shareFailed) {
          return SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BeeStatus(
                    label:
                        _saveFailed ? l.logShareSaveFailed : l.logShareFailed,
                    tone: BeeTone.error,
                  ),
                  const SizedBox(height: 10),
                  Text(file.fileName,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: BeeButton(
                      key: const ValueKey('log-share-save'),
                      label: l.logShareSaveFile,
                      kind: BeeButtonKind.secondary,
                      onPressed: _busy ? null : () => _save(file),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: send),
                  ]),
                ]),
          );
        }
        final theme = Theme.of(context);
        return SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.logShareScope(snapshot.count),
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(l.logShareOriginalHint,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .70))),
            const SizedBox(height: 12),
            _FilePreview(key: ObjectKey(file), text: file.text, busy: _busy),
            const SizedBox(height: 12),
            send,
          ]),
        );
      },
    );
  }
}

/// Limit text layout to visible rows, including when a log contains a long
/// single-line payload. These line breaks exist only in the preview.
class _FilePreview extends StatefulWidget {
  const _FilePreview({super.key, required this.text, required this.busy});
  final String text;
  final bool busy;

  @override
  State<_FilePreview> createState() => _FilePreviewState();
}

class _FilePreviewState extends State<_FilePreview> {
  bool _expanded = true;
  bool _reading = false;
  late final List<String> _rows = [
    for (final line in const LineSplitter().convert(widget.text))
      ..._wrapLongLine(line),
  ];
  // A dated section starts the actual log records. Keep the file header
  // reachable above it even when large text makes the header taller.
  static final _dateHeading = RegExp(r'^--- \d{4}-\d{2}-\d{2} ---$');
  late final int _bodyStart =
      _rows.indexWhere(_dateHeading.hasMatch).clamp(0, _rows.length);

  Iterable<String> _wrapLongLine(String line) sync* {
    var start = 0;
    while (line.length - start > 1024) {
      var end = start + 1024;
      final last = line.codeUnitAt(end - 1);
      if (last >= 0xd800 && last <= 0xdbff) end--;
      yield line.substring(start, end);
      start = end;
    }
    yield line.substring(start);
  }

  Future<void> _openFullscreen() async {
    if (_reading) return;
    _reading = true;
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              _FullscreenPreview(rows: _rows, bodyStart: _bodyStart),
        ),
      );
    } finally {
      _reading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = BeeCardTheme.of(context);
    final ink = theme.colorScheme.onSurface;
    final l = AppLocalizations.of(context);
    final toggle = Semantics(
      key: const ValueKey('log-share-preview-toggle'),
      button: true,
      expanded: _expanded,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BeeUiTokens.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              BeeLineIcon('FileText', size: 16, color: ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.logSharePreview,
                    style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 13, fontWeight: FontWeight.w600, color: ink)),
              ),
              const SizedBox(width: 8),
              BeeLineIcon(_expanded ? 'ChevronUp' : 'ChevronDown',
                  size: 16, color: ink.withValues(alpha: .70)),
            ]),
          ),
        ),
      ),
    );
    final fullscreen = Tooltip(
      message: l.logShareFullscreen,
      excludeFromSemantics: true,
      child: TextButton.icon(
        key: const ValueKey('log-share-preview-fullscreen'),
        onPressed: widget.busy ? null : _openFullscreen,
        icon: const BeeLineIcon('Expand', size: 15),
        label: Text(l.logShareFullscreen),
        style: TextButton.styleFrom(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: .20),
          foregroundColor: ink,
          iconColor: ink,
          textStyle: theme.textTheme.labelLarge
              ?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(44, 30),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
    return Material(
      key: const ValueKey('log-share-preview-card'),
      color: cards.overlay,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BeeUiTokens.controlRadius),
          side: BorderSide(color: cards.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
              builder: (context, bounds) => Row(children: [
                    Expanded(child: toggle),
                    Container(width: 1, height: 19, color: cards.divider),
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: bounds.maxWidth / 2),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          child: fullscreen),
                    ),
                  ])),
          if (_expanded) ...[
            Divider(height: 1, thickness: 1, color: cards.divider),
            Container(
              height: 124,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: cards.soft,
              child: _PreviewLines(
                key: const ValueKey('log-share-preview-lines'),
                rows: _rows,
                bodyStart: _bodyStart,
                fontSize: 11,
                lineHeight: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FullscreenPreview extends StatelessWidget {
  const _FullscreenPreview({required this.rows, required this.bodyStart});
  final List<String> rows;
  final int bodyStart;

  @override
  Widget build(BuildContext context) {
    final cards = BeeCardTheme.of(context);
    return V4PageScaffold(
      key: const ValueKey('log-share-fullscreen-page'),
      body: ColoredBox(
        color: cards.overlay,
        child: Column(children: [
          BeePageHeader(
              title: AppLocalizations.of(context).logSharePreview,
              leading: const BackButton()),
          Divider(height: 1, thickness: 1, color: cards.divider),
          Expanded(
            child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 730),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: _PreviewLines(
                        key: const ValueKey('log-share-fullscreen-lines'),
                        rows: rows,
                        bodyStart: bodyStart,
                        fontSize: 15,
                        lineHeight: 1.7,
                      ),
                    ),
                  ),
                )),
          ),
        ]),
      ),
    );
  }
}

class _PreviewLines extends StatelessWidget {
  const _PreviewLines(
      {super.key,
      required this.rows,
      required this.bodyStart,
      required this.fontSize,
      required this.lineHeight});
  final List<String> rows;
  final int bodyStart;
  final double fontSize, lineHeight;

  @override
  Widget build(BuildContext context) {
    const bodyKey = ValueKey('log-preview-records');
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        fontSize: fontSize,
        height: lineHeight,
        color: theme.colorScheme.onSurface);
    return CustomScrollView(
      primary: false,
      center: bodyKey,
      slivers: [
        if (bodyStart > 0)
          SliverList.builder(
            itemCount: bodyStart,
            itemBuilder: (_, index) =>
                Text(rows[bodyStart - 1 - index], style: style),
          ),
        SliverList.builder(
          key: bodyKey,
          itemCount: rows.length - bodyStart,
          itemBuilder: (_, index) =>
              Text(rows[bodyStart + index], style: style),
        ),
      ],
    );
  }
}
