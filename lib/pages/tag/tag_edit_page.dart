import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'detail/bindings/tag_detail.dart' show tagDetailColor;
import 'editor/bindings/tag_editor.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/data/tag_seed_service.dart';

class TagEditPage extends ConsumerStatefulWidget {
  const TagEditPage({super.key, this.tag});
  final Tag? tag;
  @override
  ConsumerState<TagEditPage> createState() => _TagEditPageState();
}

class _TagEditPageState extends ConsumerState<TagEditPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.tag?.name ?? '');
  late String _color = widget.tag?.color ?? TagSeedService.getRandomColor();
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final l = AppLocalizations.of(context);
    try {
      final saved = await saveTagDraft(ref.read(repositoryProvider),
          name: _name.text, color: _color, existing: widget.tag);
      if (!mounted) return;
      ref.read(tagListRefreshProvider.notifier).state++;
      final ledger = ref.read(currentLedgerIdProvider);
      if (ledger > 0) unawaited(PostProcessor.sync(ref, ledgerId: ledger));
      if (mounted) {
        showBeeToast(context,
            widget.tag == null ? l.tagCreateSuccess : l.tagUpdateSuccess,
            tone: BeeTone.success);
        Navigator.pop(context, saved);
      }
    } on DuplicateTagName {
      if (mounted) {
        showBeeToast(context, l.tagNameDuplicate, tone: BeeTone.error);
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(context, '${l.commonError}: $e', tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = TagSeedService.getColorPalette();
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: widget.tag == null ? l.tagAddTitle : l.tagEditTitle,
          leading: const BackButton(),
          actions: [
            TextButton(
                onPressed: _saving ? null : _save,
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface),
                child: Text(l.commonSave))
          ]),
      Expanded(
          child: Form(
              key: _form,
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(17, 4, 17, 28),
                  children: [
                    BeeSurface(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                                child: BeeTag(
                                    tag: BeeTagData(
                                        'preview',
                                        _name.text.trim().isEmpty
                                            ? l.tagNameLabel
                                            : _name.text.trim(),
                                        tagDetailColor(
                                            _color,
                                            Theme.of(context)
                                                .colorScheme
                                                .primary)))))),
                    const SizedBox(height: 12),
                    BeeSurface(
                        child: BeeField(
                            label: l.tagNameLabel,
                            hint: l.tagNameHint,
                            controller: _name,
                            maxLength: 20,
                            onChanged: (_) => setState(() {}),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? l.tagNameRequired
                                    : null)),
                    const SizedBox(height: 12),
                    BeeSurface(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Text(l.tagColorLabel,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          BeeColorPalette<String>(
                              value: _color,
                              items: [
                                for (final hex in colors)
                                  BeeColorOption(
                                      value: hex,
                                      color: tagDetailColor(hex, Colors.grey),
                                      label: '${l.tagColorLabel} $hex')
                              ],
                              onChanged: _saving
                                  ? null
                                  : (value) => setState(() => _color = value))
                        ])),
                  ]))),
    ]));
  }
}
