import 'dart:async';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import 'editor/bindings/category_icon_catalog.dart';
import 'editor/bindings/category_icon_draft.dart';
import 'editor/bindings/category_line_icon_names.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import '../shared/resources/bindings/recording_category_icon.dart';
import '../../services/billing/post_processor.dart';
import '../../services/system/logger_service.dart';
import '../../utils/category_utils.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../utils/shared_ledger_picker_filter.dart';
import '../transaction/category_detail_page.dart';
import 'category_migration_page.dart';

part 'editor/bindings/category_edit_actions.dart';

class CategoryEditPage extends ConsumerStatefulWidget {
  const CategoryEditPage(
      {super.key, this.category, required this.kind, this.parentCategory});
  final db.Category? category, parentCategory;
  final String kind;
  @override
  ConsumerState<CategoryEditPage> createState() => _CategoryEditPageState();
}

class _CategoryEditPageState extends ConsumerState<CategoryEditPage>
    with _CategoryEditActions {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups = categoryEditorIconGroups(l, widget.kind);
    BeeIconChoice<String> choice(String key) => BeeIconChoice(
        value: key,
        label: key,
        icon: BeeLineIcon(categoryLineIconNames[key] ?? 'Shapes', size: 22));
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: isEditing ? l.categoryEditTitle : l.categoryNewTitle,
          leading: const BackButton(),
          actions: isEditing
              ? [
                  BeeIconButton(
                      label: l.categoryDetailTooltip,
                      icon: const BeeLineIcon('ChartPie', size: 20),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CategoryDetailPage(
                                  categoryId: widget.category!.id,
                                  categoryName: widget.category!.name,
                                  allLedgers: true)))),
                  BeeIconButton(
                      label: l.categoryMigrationTooltip,
                      icon: const BeeLineIcon('ArrowLeftRight', size: 20),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CategoryMigrationPage(
                                  preselectedFromCategory: widget.category!))))
                ]
              : const []),
      Expanded(
          child: Form(
              key: _formKey,
              child: BeePageBody(children: [
                BeeSurface(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      BeeField(
                          label: l.categoryNameLabel,
                          hint: l.categoryNameHint,
                          controller: _nameController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 10,
                          enabled: !_busy,
                          error: _duplicate ? l.categoryNameDuplicate : null,
                          textInputAction: TextInputAction.done,
                          validator: (v) => (v?.trim().isEmpty ?? true)
                              ? l.categoryNameRequired
                              : v!.trim().length > 10
                                  ? l.categoryNameTooLong
                                  : _duplicate
                                      ? l.categoryNameDuplicate
                                      : null),
                      const SizedBox(height: 10),
                      BeeMenuRow(
                          title: widget.kind == 'expense'
                              ? l.categoryExpenseType
                              : widget.kind == 'income'
                                  ? l.categoryIncomeType
                                  : l.transferTitle,
                          leading: BeeLineIcon(
                              widget.kind == 'transfer'
                                  ? 'ArrowLeftRight'
                                  : widget.kind == 'expense'
                                      ? 'TrendingDown'
                                      : 'TrendingUp',
                              size: 20),
                          trailing: const SizedBox.shrink()),
                      const Divider(height: 1),
                      BeeToggleRow(
                          title: l.categorySubCategoryTitle,
                          subtitle: _isSubCategory
                              ? l.categorySubCategoryDescriptionEnabled
                              : l.categorySubCategoryDescriptionDisabled,
                          value: _isSubCategory,
                          onChanged: _busy ||
                                  isEditing ||
                                  widget.parentCategory != null
                              ? null
                              : (v) => setState(() {
                                    _isSubCategory = v;
                                    if (!v) _parent = null;
                                  })),
                      if (_isSubCategory)
                        BeeMenuRow(
                            title: l.categoryParentCategoryTitle,
                            subtitle: _parent == null
                                ? l.categoryParentCategoryHint
                                : CategoryUtils.getDisplayName(
                                    _parent!.name, context),
                            leading: _parent == null
                                ? const BeeLineIcon('Shapes', size: 20)
                                : RecordingCategoryIcon(
                                    category: _parent!, size: 20),
                            onTap: _busy || widget.parentCategory != null
                                ? null
                                : _selectParent,
                            trailing: widget.parentCategory != null
                                ? const SizedBox.shrink()
                                : null)
                    ])),
                BeeSurface(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text(l.categoryIconLabel,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      BeeCategoryIconEditor(
                          source: _iconSource,
                          value: _icon,
                          enabled: !_busy,
                          loading: _picking,
                          groups: [
                            for (var i = 0; i < groups.length; i++)
                              BeeCategoryIconGroup(
                                  id: '$i',
                                  label: groups[i].label,
                                  items:
                                      groups[i].iconKeys.map(choice).toList())
                          ],
                          commonItems: (widget.kind == 'expense'
                                  ? [
                                      'restaurant',
                                      'local_cafe',
                                      'directions_subway',
                                      'shopping_basket',
                                      'home',
                                      'movie',
                                      'book',
                                      'favorite',
                                      'card_giftcard',
                                      'computer',
                                      'fitness_center',
                                      'pets'
                                    ]
                                  : [
                                      'work',
                                      'account_balance',
                                      'savings',
                                      'card_giftcard',
                                      'paid',
                                      'trending_up',
                                      'wallet',
                                      'emoji_events',
                                      'handshake',
                                      'undo',
                                      'sync',
                                      'category'
                                    ])
                              .map(choice)
                              .toList(),
                          presetLabel: l.v4CategoryPresetIcons,
                          customLabel: l.categoryCustomIconTitle,
                          commonLabel: l.v4CategoryCommonIcons,
                          imageHint: l.v4CategoryImageHint,
                          chooseImageLabel: _customPath == null
                              ? l.categoryCustomIconTapToSelect
                              : l.categoryCustomIconTapToChange,
                          preview: _customPreview(),
                          onSourceChanged: (v) =>
                              setState(() => _iconSource = v),
                          onChanged: (v) => setState(() {
                                _icon = v;
                                _iconSource = BeeCategoryIconSource.preset;
                              }),
                          onChooseImage: _pickIcon)
                    ])),
                if (isEditing)
                  BeeSurface(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: BeeMenuRow(
                          title: l.categoryDeleteTitle,
                          subtitle: l.categoryDeleteSubtitle,
                          danger: true,
                          leading: BeeLineIcon('Trash2',
                              size: 20,
                              color: Theme.of(context).colorScheme.error),
                          onTap: _busy ? null : _deleteCategory))
              ]))),
      SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 8, 17, 12),
              child: SizedBox(
                  width: double.infinity,
                  child: BeeButton(
                      label: l.commonSave,
                      loading: _busy,
                      onPressed: _busy || _picking || _duplicate
                          ? null
                          : _saveCategory))))
    ]));
  }

  Widget? _customPreview() {
    if (_customPath == null) return null;
    return FutureBuilder<String?>(
        future: _resolvedIcon,
        builder: (context, snap) => snap.connectionState != ConnectionState.done
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : snap.data == null
                ? const BeeLineIcon('ImageOff')
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(snap.data!),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Center(child: BeeLineIcon('ImageOff')))));
  }
}
