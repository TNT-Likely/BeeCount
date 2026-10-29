import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// The host resolves identity, role, permissions and image URLs.
class RecordingAuthor {
  const RecordingAuthor(
      {required this.name, required this.tooltip, this.image});
  final String name, tooltip;
  final ImageProvider? image;
}

class RecordingAuthors extends StatelessWidget {
  const RecordingAuthors({super.key, required this.authors});
  final List<RecordingAuthor> authors;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < authors.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Tooltip(
              message: authors[i].tooltip,
              triggerMode: TooltipTriggerMode.longPress,
              child: CircleAvatar(
                  radius: 11,
                  backgroundColor: BeeCardTheme.of(context).soft,
                  foregroundImage: authors[i].image,
                  onForegroundImageError:
                      authors[i].image == null ? null : (_, __) {},
                  child: Text(
                      authors[i].name.isEmpty
                          ? '?'
                          : authors[i].name.characters.first.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: .65)))))
        ]
      ]);
}

class RecordingCurrencyControl extends StatelessWidget {
  const RecordingCurrencyControl(
      {super.key,
      required this.currency,
      this.onTap,
      this.leading,
      this.legacy = false});
  final String currency;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool legacy;
  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return Text(currency,
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor));
    }
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(legacy ? 8 : 10),
        child: Container(
            constraints: BoxConstraints(minHeight: legacy ? 0 : 30),
            padding:
                EdgeInsets.symmetric(horizontal: 8, vertical: legacy ? 5 : 3),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(legacy ? 8 : 10),
                color: legacy ? BeeCardTheme.of(context).soft : null,
                border: legacy
                    ? null
                    : Border.all(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: .18))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (leading != null) ...[leading!, const SizedBox(width: 5)],
              Text(currency,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: legacy
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: .65)
                          : null)),
              SizedBox(width: legacy ? 0 : 5),
              BeeLineIcon('ChevronDown', size: legacy ? 16 : 12)
            ])));
  }
}

class RecordingMetaControl extends StatelessWidget {
  const RecordingMetaControl(
      {super.key,
      required this.label,
      required this.onTap,
      this.icon,
      this.child,
      this.fontSize = 12});
  final String label;
  final VoidCallback? onTap;
  final String? icon;
  final Widget? child;
  final double fontSize;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
          height: 44,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null && icon!.isNotEmpty) ...[
              BeeLineIcon(icon!, size: 16),
              const SizedBox(width: 5)
            ],
            Flexible(
                child: child ??
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: fontSize))),
          ])));
}

class RecordingLedgerControl extends StatelessWidget {
  const RecordingLedgerControl({super.key, required this.name, this.onTap});
  final String name;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Flexible(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: Theme.of(context).hintColor))),
        if (onTap != null) ...[
          const SizedBox(width: 5),
          BeeLineIcon('ChevronDown',
              size: 16, color: Theme.of(context).hintColor)
        ]
      ]));
}

/// Focus, draft text and history lookup stay in the calling binding.
class RecordingNoteField extends StatelessWidget {
  const RecordingNoteField(
      {super.key,
      required this.controller,
      required this.focusNode,
      required this.hint,
      this.fieldKey,
      this.onChanged,
      this.historyLabel,
      this.onHistory,
      this.historyKey,
      this.inline = true});
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;
  final String? historyLabel;
  final VoidCallback? onHistory;
  final Key? historyKey;
  final bool inline;
  @override
  Widget build(BuildContext context) => TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: TextStyle(fontSize: inline ? 12 : null),
      decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          border: inline
              ? InputBorder.none
              : OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
          filled: !inline,
          fillColor: inline ? null : BeeCardTheme.of(context).soft,
          contentPadding: inline
              ? const EdgeInsets.symmetric(vertical: 12)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          prefixIconConstraints: onHistory == null
              ? null
              : BoxConstraints(
                  minWidth: inline ? 24 : 40, minHeight: inline ? 32 : 20),
          prefixIcon: onHistory == null
              ? null
              : Tooltip(
                  message: historyLabel ?? '',
                  child: Semantics(
                      label: historyLabel,
                      button: true,
                      child: InkWell(
                          key: historyKey,
                          onTap: onHistory,
                          child: Padding(
                              padding: EdgeInsets.only(right: inline ? 8 : 0),
                              child: BeeLineIcon(
                                  inline ? 'PencilLine' : 'History',
                                  size: inline ? 16 : 20,
                                  color: Theme.of(context).hintColor)))))));
}

class RecordingAttachmentControl extends StatelessWidget {
  const RecordingAttachmentControl(
      {super.key,
      required this.label,
      required this.count,
      required this.onTap});
  final String label;
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => BeeIconButton(
      label: label,
      onPressed: onTap,
      icon: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: BeeLineIcon('ImagePlus',
              size: 18, color: Theme.of(context).hintColor)));
}

class RecordingTagAttachmentBar extends StatelessWidget {
  const RecordingTagAttachmentBar(
      {super.key,
      required this.tags,
      required this.emptyLabel,
      required this.onTags,
      required this.attachmentCount,
      required this.onAttachments,
      this.trailing});
  final List<Widget> tags;
  final String emptyLabel;
  final VoidCallback onTags, onAttachments;
  final int attachmentCount;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: BeeCardTheme.of(context).soft,
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
            child: GestureDetector(
                onTap: onTags,
                behavior: HitTestBehavior.opaque,
                child: tags.isEmpty
                    ? Text(emptyLabel,
                        style: TextStyle(
                            fontSize: 14, color: Theme.of(context).hintColor))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final tag in tags)
                            Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: tag)
                        ])))),
        const SizedBox(width: 16),
        GestureDetector(
            onTap: onAttachments,
            behavior: HitTestBehavior.opaque,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(attachmentCount > 0 ? Icons.image : Icons.image_outlined,
                  size: 18,
                  color: attachmentCount > 0
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).hintColor),
              if (attachmentCount > 0) ...[
                const SizedBox(width: 4),
                Text('$attachmentCount',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary))
              ]
            ])),
        if (trailing != null) trailing!
      ]));
}

class RecordingAccountControl extends StatelessWidget {
  const RecordingAccountControl(
      {super.key,
      required this.label,
      required this.onTap,
      this.icon,
      this.fontSize = 12});
  final String label;
  final Widget? icon;
  final double fontSize;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => RecordingMetaControl(
      label: label,
      onTap: onTap,
      child: Row(children: [
        if (icon != null) ...[icon!, const SizedBox(width: 5)],
        Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSize))),
        const SizedBox(width: 3),
        const BeeLineIcon('ChevronDown', size: 12)
      ]));
}

class RecordingTagSummary extends StatelessWidget {
  const RecordingTagSummary(
      {super.key, required this.first, required this.count});
  final Widget first;
  final int count;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: first),
        if (count > 1) ...[
          const SizedBox(width: 3),
          Text('+${count - 1}',
              style:
                  TextStyle(fontSize: 10, color: Theme.of(context).hintColor))
        ]
      ]);
}

class RecordingNoteToggle extends StatelessWidget {
  const RecordingNoteToggle(
      {super.key,
      required this.expanded,
      required this.label,
      required this.onTap});
  final bool expanded;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: label,
      constraints: const BoxConstraints.tightFor(width: 32, height: 44),
      padding: EdgeInsets.zero,
      onPressed: onTap,
      icon: BeeLineIcon(expanded ? 'ChevronUp' : 'PencilLine', size: 17));
}

class RecordingLegacyAmount extends StatelessWidget {
  const RecordingLegacyAmount(
      {super.key,
      required this.amount,
      required this.currency,
      this.authors,
      this.accumulated,
      this.operator,
      this.result,
      this.conversion});
  final String amount;
  final String? accumulated, operator, result;
  final Widget currency;
  final Widget? authors, conversion;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme,
        scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(children: [
        if (authors != null) authors!,
        const Spacer(),
        currency,
        const SizedBox(width: 6),
        if (operator != null) ...[
          Text(accumulated ?? '',
              style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface.withValues(alpha: .65))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(operator!,
                  style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600, color: scheme.primary)))
        ],
        Text(amount,
            style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: scheme.onSurface))
      ]),
      if (result != null) ...[
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('= ',
              style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).hintColor)),
          Text(result!,
              style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600, color: scheme.primary))
        ])
      ],
      if (conversion != null) conversion!
    ]);
  }
}

class RecordingConversionHint extends StatelessWidget {
  const RecordingConversionHint(
      {super.key, required this.text, this.error = false, this.onTap});
  final String text;
  final bool error;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        InkWell(
            onTap: onTap,
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: error
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).hintColor)))
      ]));
}

class RecordingFlagControl extends StatelessWidget {
  const RecordingFlagControl(
      {super.key,
      required this.active,
      required this.label,
      required this.onTap});
  final bool active;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: label,
      child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Icon(active ? Icons.flag : Icons.outlined_flag,
              size: 18,
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).hintColor)));
}

class RecordingFlagOption {
  const RecordingFlagOption(
      {required this.title,
      required this.hint,
      required this.value,
      required this.onChanged});
  final String title, hint;
  final bool value;
  final ValueChanged<bool> onChanged;
}

class RecordingFlagsForm extends StatelessWidget {
  const RecordingFlagsForm(
      {super.key,
      required this.options,
      this.titleSize = 15,
      this.hintSize = 12});
  final List<RecordingFlagOption> options;
  final double titleSize, hintSize;
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final option in options)
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(option.title,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: titleSize)),
                  subtitle: Text(option.hint,
                      style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: hintSize)),
                  value: option.value,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: option.onChanged)
          ]);
}
