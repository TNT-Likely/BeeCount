import 'dart:io';

import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../services/attachment_service.dart';
import 'attachment_source.dart';

/// Real file access, repository mutations and platform pickers stay in the App.
class AttachmentViewerBinding extends ConsumerStatefulWidget {
  const AttachmentViewerBinding(
      {super.key,
      this.attachments,
      this.transactionId,
      this.initialIndex = 0,
      this.allowDelete = true,
      this.allowAdd = false,
      this.pendingFiles,
      this.onPendingFilesChanged});
  final List<TransactionAttachment>? attachments;
  final int? transactionId;
  final int initialIndex;
  final bool allowDelete, allowAdd;
  final List<File>? pendingFiles;
  final ValueChanged<List<File>>? onPendingFilesChanged;
  @override
  ConsumerState<AttachmentViewerBinding> createState() =>
      _AttachmentViewerBindingState();
}

class _AttachmentViewerBindingState
    extends ConsumerState<AttachmentViewerBinding> {
  late int _index = widget.initialIndex;
  List<TransactionAttachment> _saved = [];
  late final List<File> _pending = List.from(widget.pendingFiles ?? []);
  String _directory = '';
  bool _loading = true, _failed = false, _busy = false;
  int get _count => _saved.length + _pending.length;
  int _bounded(int index) => index.clamp(0, _count == 0 ? 0 : _count - 1);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _load();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final direct = widget.attachments;
      final List<TransactionAttachment> saved;
      if (direct != null) {
        saved = direct;
      } else if (widget.transactionId != null) {
        saved = await ref
            .read(transactionAttachmentsProvider(widget.transactionId!).future);
      } else {
        saved = [];
      }
      final directory =
          await ref.read(attachmentServiceProvider).getAttachmentDirectory();
      if (!mounted) return;
      setState(() {
        _saved = List.from(saved);
        _directory = directory.path;
        _index = _bounded(_index);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  void _close() {
    if (!_busy) Navigator.pop(context, List<File>.from(_pending));
  }

  void _emitPending() =>
      widget.onPendingFilesChanged?.call(List<File>.from(_pending));
  String _size(int? bytes) {
    final value = bytes ?? 0;
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return value >= 1024 ? '${(value / 1024).round()} KB' : '$value B';
  }

  List<BeeAttachment> _models(AppLocalizations l10n) => [
        ..._saved.map((a) => BeeAttachment(
            id: 'saved-${a.id}',
            image: FileImage(File('$_directory/${a.fileName}')),
            label: a.originalName ?? l10n.attachmentPreview,
            info:
                '${_size(a.fileSize)}${a.width != null && a.height != null ? ' · ${a.width}×${a.height}' : ''}')),
        ..._pending.map((f) => BeeAttachment(
            id: 'pending-${f.path}',
            image: FileImage(f),
            label: l10n.attachmentPreview,
            info: l10n.v4AttachmentPending)),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saved = _index < _saved.length;
    final placeholder = _loading
        ? const CircularProgressIndicator(color: Colors.white)
        : _failed
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l10n.commonError,
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                BeeButton(label: l10n.v4RecordingRetry, onPressed: _load),
              ])
            : null;
    return Scaffold(
        backgroundColor: Colors.black,
        body: BeeAttachmentViewer(
            items: _loading || _failed ? const [] : _models(l10n),
            currentIndex: _index,
            fullScreen: true,
            busy: _busy,
            maxScale: 4,
            onIndexChanged: (index) => setState(() => _index = index),
            onClose: _close,
            onImageTap: _close,
            emptyLabel:
                _loading ? l10n.attachmentPreview : l10n.attachmentPreviewEmpty,
            errorLabel: l10n.commonError,
            placeholder: placeholder,
            actions: [
              if (!_loading &&
                  !_failed &&
                  widget.allowAdd &&
                  _count < AttachmentService.maxAttachments)
                BeeIconButton(
                    label: l10n.attachmentAdd,
                    icon: const BeeLineIcon('ImagePlus', color: Colors.white),
                    onPressed: _busy ? null : _sources),
              if (!_loading && !_failed && widget.allowDelete && _count > 0)
                BeeIconButton(
                    label: l10n.commonDelete,
                    icon: const BeeLineIcon('Trash2', color: Colors.white),
                    onPressed: _busy
                        ? null
                        : () => saved ? _deleteSaved() : _deletePending()),
            ]));
  }

  Future<void> _sources() async {
    final files = await pickAttachmentFiles(context, ref,
        remaining: AttachmentService.maxAttachments - _count);
    if (files.isNotEmpty && mounted) await _add(files);
  }

  Future<void> _add(List<File> files) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(attachmentServiceProvider);
      for (final file in files) {
        if (!mounted || _count >= AttachmentService.maxAttachments) break;
        if (widget.transactionId != null) {
          final row = await service.saveAttachment(
              transactionId: widget.transactionId!,
              sourceFile: file,
              index: _saved.length);
          if (!mounted) return;
          if (row != null) {
            setState(() {
              _saved.add(row);
              _index = _saved.length - 1;
            });
            ref.read(attachmentListRefreshProvider.notifier).state++;
          }
        } else {
          setState(() {
            _pending.add(file);
            _index = _count - 1;
          });
          _emitPending();
        }
      }
    } catch (_) {
      if (mounted) {
        showBeeToast(context, AppLocalizations.of(context).commonError,
            tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSaved() async {
    if (_busy || _index >= _saved.length) return;
    final l10n = AppLocalizations.of(context);
    final row = _saved[_index];
    final confirmed = await showBeeConfirm(context,
        title: l10n.deleteConfirmTitle,
        message: l10n.attachmentDeleteConfirm,
        confirmLabel: l10n.commonDelete,
        cancelLabel: l10n.commonCancel,
        danger: true);
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(attachmentServiceProvider).deleteAttachment(row.id);
      // The legacy service logs I/O/repository failures instead of throwing.
      // Keep the image visible when its database record was not removed.
      if (await ref.read(repositoryProvider).getAttachmentById(row.id) !=
          null) {
        throw StateError('Attachment deletion did not persist');
      }
      if (!mounted) return;
      ref.read(attachmentListRefreshProvider.notifier).state++;
      setState(() {
        _saved.removeWhere((a) => a.id == row.id);
        _index = _bounded(_index);
        _busy = false;
      });
      showBeeToast(context, l10n.commonDeleted, tone: BeeTone.success);
      if (_count == 0) _close();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showBeeToast(context, l10n.commonError, tone: BeeTone.error);
      }
    }
  }

  void _deletePending() {
    if (_busy || _index < _saved.length) return;
    setState(() {
      _pending.removeAt(_index - _saved.length);
      _index = _bounded(_index);
    });
    _emitPending();
    if (_count == 0) _close();
  }
}
