import 'dart:typed_data';

import 'package:beecount_business_ui/share_card.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../services/export/share_poster_service.dart';
import '../../../services/export/share_poster_types.dart';
import '../../../widgets/ui/ui.dart' show showToast;
import 'share_card_platform.dart';
import 'share_card_renderer.dart';

class ShareCardDialog extends StatelessWidget {
  const ShareCardDialog(
      {super.key,
      this.year,
      this.month,
      this.ledgerId,
      this.type,
      this.imageBytes});
  final int? year, month, ledgerId;
  final String? type;
  final Uint8List? imageBytes;
  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: BeeCardTheme.of(context).surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .85,
                child: ShareCardControls(
                    year: year,
                    month: month,
                    ledgerId: ledgerId,
                    type: type,
                    imageBytes: imageBytes))),
      );
}

/// Identical body for the original production dialogs and the debug thin page.
class ShareCardControls extends ConsumerStatefulWidget {
  const ShareCardControls(
      {super.key,
      this.year,
      this.month,
      this.ledgerId,
      this.type,
      this.imageBytes,
      this.previewOnly = false});
  final int? year, month, ledgerId;
  final String? type;
  final Uint8List? imageBytes;
  final bool previewOnly;
  @override
  ConsumerState<ShareCardControls> createState() => _ShareCardControlsState();
}

class _ShareCardControlsState extends ConsumerState<ShareCardControls> {
  late final List<PosterType> _types = widget.imageBytes != null
      ? []
      : widget.type != null
          ? [
              switch (widget.type) {
                'year' => PosterType.yearSummary,
                'month' => PosterType.monthSummary,
                'ledger' => PosterType.ledgerSummary,
                _ => PosterType.appPromo,
              }
            ]
          : widget.month != null
              ? [PosterType.monthSummary]
              : widget.year != null
                  ? [PosterType.yearSummary]
                  : [PosterType.userProfile, PosterType.appPromo];
  final _cache = <(PosterType, bool), Uint8List>{};
  int _index = 0, _generation = 0;
  bool _hideIncome = false,
      _generating = false,
      _busy = false,
      _sharing = false;
  String? _error;
  Uint8List? _image;
  bool get _hasPrivacy =>
      _types.isNotEmpty &&
      _types[_index] != PosterType.appPromo &&
      _types[_index] != PosterType.userProfile;

  @override
  void initState() {
    super.initState();
    _image = widget.imageBytes;
    if (_image == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generate();
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _generate() async {
    final token = ++_generation;
    final type = _types[_index];
    final key = (type, _hideIncome);
    setState(() {
      _image = _cache[key];
      _generating = _image == null;
      _error = null;
    });
    if (_image != null) return;
    try {
      if (widget.type != null &&
          !{'year', 'month', 'ledger'}.contains(widget.type)) {
        throw StateError('Unsupported poster type');
      }
      final ledgerId =
          widget.ledgerId ?? ref.read(currentLedgerIdProvider) ?? 0;
      if (type != PosterType.appPromo && ledgerId == 0) {
        throw _ShareCardNoLedger();
      }
      final bytes = await ref.read(shareCardRendererProvider).generate(
          context, ref,
          type: type,
          hideIncome: _hideIncome,
          ledgerId: ledgerId,
          year: widget.year,
          month: widget.month);
      if (!mounted || token != _generation) return;
      setState(() {
        _generating = false;
        _image = bytes;
        if (bytes == null) {
          _error = AppLocalizations.of(context).sharePosterGenerateFailed;
        } else {
          _cache[key] = bytes;
        }
      });
    } catch (error) {
      if (!mounted || token != _generation) return;
      setState(() {
        _generating = false;
        _error = error is _ShareCardNoLedger
            ? AppLocalizations.of(context).sharePosterNoLedger
            : AppLocalizations.of(context).sharePosterGenerateFailed;
      });
    }
  }

  Future<void> _export({Rect? anchor}) async {
    final bytes = _image;
    if (_busy || _generating || bytes == null || widget.previewOnly) return;
    setState(() {
      _busy = true;
      _sharing = anchor != null;
      _error = null;
    });
    final l = AppLocalizations.of(context);
    try {
      if (anchor != null) {
        // Dismissed/unavailable share sheets are not reported as success/error.
        await ref.read(shareCardPlatformProvider).share(bytes, anchor);
      } else {
        final result = await ref.read(shareCardPlatformProvider).save(bytes);
        if (!mounted) return;
        if (result == SavePosterResult.success) {
          showToast(context, l.sharePosterSaveSuccess);
          Navigator.pop(context);
        } else {
          setState(() => _error = result == SavePosterResult.accessDenied
              ? l.sharePosterPermissionDenied
              : l.sharePosterSaveFailed);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = anchor == null ? l.sharePosterSaveFailed : l.commonError);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _label(AppLocalizations l, PosterType type) => switch (type) {
        PosterType.userProfile => l.v4ShareCardProfile,
        PosterType.appPromo => l.mineShareApp,
        PosterType.monthSummary => l.sharePosterMonthTitle,
        PosterType.yearSummary => l.sharePosterYearTitle,
        PosterType.ledgerSummary => l.sharePosterLedgerTitle,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeShareCard(
      title: l.v4ShareCardTitle,
      closeLabel: l.commonClose,
      saveLabel: l.sharePosterSave,
      shareLabel: l.sharePosterShare,
      generatingLabel: l.sharePosterGenerating,
      retryLabel: l.helpCenterRetry,
      templates: [
        for (final type in _types)
          BeeShareCardTemplate(type.name, _label(l, type))
      ],
      selected: _types.isEmpty ? '' : _types[_index].name,
      onTemplate: (name) {
        setState(() => _index = _types.indexWhere((t) => t.name == name));
        _generate();
      },
      preview: _image == null
          ? const Icon(Icons.image_outlined, size: 64)
          : Image.memory(_image!,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stack) =>
                  Text(l.sharePosterGenerateFailed)),
      onClose: () => Navigator.maybePop(context),
      onSave: _image == null || widget.previewOnly ? null : () => _export(),
      onShare: _image == null || widget.previewOnly
          ? null
          : (anchor) => _export(anchor: anchor),
      onRetry: _image == null && _types.isNotEmpty ? _generate : null,
      generating: _generating,
      busy: _busy,
      sharing: _sharing,
      error: _error,
      hideIncome: _hideIncome,
      privacyLabel: _hasPrivacy
          ? (_hideIncome ? l.sharePosterShowIncome : l.sharePosterHideIncome)
          : null,
      onPrivacy: () {
        setState(() => _hideIncome = !_hideIncome);
        _generate();
      },
    );
  }
}

class _ShareCardNoLedger implements Exception {}
