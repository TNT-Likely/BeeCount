import 'dart:async';

import 'package:flutter/material.dart';

import '../../ai/providers/xiaomi_mimo_profile.dart';
import '../../ai/providers/deepseek_profile.dart';
import '../../ai/providers/provider_models.dart';
import '../../l10n/app_localizations.dart';

typedef ProviderModelLoader = Future<ProviderModels> Function(String apiKey);

/// Model discovery belongs to the provider editor, never to a test button.
class ProviderModelSettings extends StatefulWidget {
  const ProviderModelSettings(
      {super.key,
      required this.apiKey,
      required this.textModel,
      required this.visionModel,
      required this.audioModel,
      required this.onChanged,
      this.loadModels = XiaomiMiMoProfile.discover,
      this.preferredModel = XiaomiMiMoProfile.generationModel,
      this.showSpeech = true});

  final String preferredModel;
  final bool showSpeech;
  final String apiKey;
  final String textModel;
  final String visionModel;
  final String audioModel;
  final void Function(String text, String vision, String speech) onChanged;
  final ProviderModelLoader loadModels;

  @override
  State<ProviderModelSettings> createState() => _ProviderModelSettingsState();
}

class _ProviderModelSettingsState extends State<ProviderModelSettings> {
  Timer? _debounce;
  int _request = 0;
  bool _loading = false;
  ProviderModels? _models;
  String? _error;
  bool _unauthorized = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(ProviderModelSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiKey != widget.apiKey) {
      _request++;
      _models = null;
      _error = null;
      _loading = false;
      _schedule();
    }
  }

  void _schedule() {
    _debounce?.cancel();
    if (widget.apiKey.trim().isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 600), _load);
    }
  }

  Future<void> _load() async {
    _debounce?.cancel();
    final request = ++_request;
    final key = widget.apiKey.trim();
    if (key.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final models = await widget.loadModels(key);
      if (!mounted || request != _request) return;
      final text = ProviderModels.select(
          models.text, widget.textModel, widget.preferredModel);
      final vision = ProviderModels.select(
          models.vision, widget.visionModel, widget.preferredModel);
      final speech = ProviderModels.select(
          models.speech, widget.audioModel, XiaomiMiMoProfile.asrModel);
      setState(() {
        _models = models;
        _loading = false;
        _unavailable = (widget.textModel.isNotEmpty &&
                text != widget.textModel) ||
            (widget.visionModel.isNotEmpty && vision != widget.visionModel) ||
            (widget.audioModel.isNotEmpty && speech != widget.audioModel);
      });
      widget.onChanged(text, vision, speech);
    } on Object catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _models = null;
        _error = 'failed';
        _unauthorized =
            (error is XiaomiMiMoModelLoadException && error.unauthorized) ||
                (error is ProviderModelLoadException && error.unauthorized);
      });
    }
  }

  @override
  void dispose() {
    _request++;
    _debounce?.cancel();
    super.dispose();
  }

  Widget _dropdown(String label, String value, List<String>? available,
      ValueChanged<String> onChanged) {
    // Until a successful refresh retain the saved model, without permitting
    // free-form IDs. An authoritative empty list clears unavailable choices.
    final items = available ?? (value.isEmpty ? <String>[] : [value]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true),
        items: [
          for (final id in items)
            DropdownMenuItem(
                value: id, child: Text(id, overflow: TextOverflow.ellipsis))
        ],
        onChanged: _loading || available == null
            ? null
            : (id) {
                if (id != null) onChanged(id);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.apiKey.trim().isEmpty) Text(l10n.aiMiMoModelsMissingKey),
      if (_loading) ...[
        const LinearProgressIndicator(),
        Text(l10n.aiMiMoModelsLoading),
      ],
      if (_error != null)
        Text(_unauthorized
            ? l10n.aiMiMoModelsUnauthorized
            : l10n.aiMiMoModelsFailed),
      if (_unavailable && _models != null) Text(l10n.aiMiMoModelUnavailable),
      if (_models != null)
        Text(_models!.text.isEmpty &&
                _models!.vision.isEmpty &&
                _models!.speech.isEmpty
            ? l10n.aiMiMoModelsEmpty
            : l10n.aiMiMoModelsLoaded),
      const SizedBox(height: 16),
      _dropdown(
          l10n.aiTextModelTitle,
          widget.textModel,
          _models?.text,
          (value) =>
              widget.onChanged(value, widget.visionModel, widget.audioModel)),
      _dropdown(
          l10n.aiVisionModelTitle,
          widget.visionModel,
          _models?.vision,
          (value) =>
              widget.onChanged(widget.textModel, value, widget.audioModel)),
      if (widget.showSpeech)
        _dropdown(
            l10n.aiAudioModelTitle,
            widget.audioModel,
            _models?.speech,
            (value) =>
                widget.onChanged(widget.textModel, widget.visionModel, value)),
      OutlinedButton.icon(
          onPressed: _loading || widget.apiKey.trim().isEmpty ? null : _load,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.aiMiMoModelsRefresh)),
    ]);
  }
}
