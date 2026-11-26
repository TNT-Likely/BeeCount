import 'dart:convert';

import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../services/system/log_export_service.dart';
import '../../../../services/system/logger_service.dart';

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
  bool _redacted = false;
  bool _previewOpen = true;
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
        final file = snapshot.file(redacted: _redacted);
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
        return SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.logShareScope(snapshot.count)),
            const SizedBox(height: 10),
            Row(children: [
              for (final redacted in [false, true]) ...[
                if (redacted) const SizedBox(width: 8),
                Expanded(
                    child: ChoiceChip(
                  key: ValueKey(
                      redacted ? 'log-share-redacted' : 'log-share-original'),
                  label:
                      Text(redacted ? l.logShareRedacted : l.logShareOriginal),
                  selected: redacted == _redacted,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _redacted = redacted),
                )),
              ],
            ]),
            const SizedBox(height: 5),
            Text(_redacted ? l.logShareRedactedHint : l.logShareOriginalHint,
                style: Theme.of(context).textTheme.bodySmall),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _previewOpen = !_previewOpen),
                icon: Icon(_previewOpen ? Icons.expand_less : Icons.expand_more,
                    size: 18),
                label: Text(l.logSharePreview),
              ),
            ),
            if (_previewOpen)
              _FilePreview(key: ObjectKey(file), text: file.text),
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
  const _FilePreview({super.key, required this.text});
  final String text;

  @override
  State<_FilePreview> createState() => _FilePreviewState();
}

class _FilePreviewState extends State<_FilePreview> {
  late final List<String> _rows = [
    for (final line in const LineSplitter().convert(widget.text))
      ..._wrapLongLine(line),
  ];

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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 124,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: BeeCardTheme.of(context).soft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: ListView.builder(
        primary: false,
        itemCount: _rows.length,
        itemBuilder: (_, index) => Text(_rows[index],
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace', fontSize: 11, height: 1.55)),
      ),
    );
  }
}
