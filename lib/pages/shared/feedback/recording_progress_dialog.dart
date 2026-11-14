import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../branding/bee_artwork.dart';

/// The operation owns its notifier. Only real extraction/persistence events
/// change the stage; elapsed time adds a hint, never a made-up progress value.
class RecordingProgressDialog extends StatefulWidget {
  const RecordingProgressDialog({
    super.key,
    required this.saving,
    required this.sourceLabel,
    this.ledgerName,
    this.voice = false,
  });
  final ValueListenable<bool> saving;
  final String sourceLabel;
  final String? ledgerName;
  final bool voice;
  @override
  State<RecordingProgressDialog> createState() =>
      _RecordingProgressDialogState();
}

class _RecordingProgressDialogState extends State<RecordingProgressDialog> {
  Timer? _timer;
  bool _slow = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
        canPop: false,
        child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
            child: SingleChildScrollView(
                child: ValueListenableBuilder<bool>(
                    valueListenable: widget.saving,
                    builder: (context, saving, _) => RecordingProgressCard(
                        title: saving
                            ? l.recordingProgressSaving
                            : l.recordingProgressRecognizing,
                        description: saving
                            ? l.recordingProgressSavingDetail
                            : l.recordingProgressRecognizingDetail,
                        contextLabel: [
                          widget.sourceLabel,
                          if (widget.ledgerName?.isNotEmpty == true)
                            widget.ledgerName!
                        ].join(' · '),
                        contextIcon: BeeLineIcon(widget.voice ? 'Mic' : 'Image',
                            size: 12),
                        mark: BeeIcon(
                            color: Theme.of(context).colorScheme.primary,
                            size: 40),
                        waitHint: _slow ? l.recordingProgressSlow : null)))));
  }
}
