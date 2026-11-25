import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A draft stays editable while the current answer is running. The parent owns
/// the controller, submitting/cancelling the turn, and presentation of shortcuts.
class BeeConversationInput extends StatelessWidget {
  const BeeConversationInput({
    super.key,
    required this.controller,
    required this.hint,
    required this.sendLabel,
    required this.stopLabel,
    required this.busy,
    required this.onSend,
    required this.onStop,
    this.onQuickActions,
    this.quickActionsLabel,
    this.enabled = true,
    this.focusNode,
  }) : assert(onQuickActions == null || quickActionsLabel != null);

  final TextEditingController controller;
  final String hint, sendLabel, stopLabel;
  final bool busy, enabled;
  final VoidCallback onSend, onStop;
  final VoidCallback? onQuickActions;
  final String? quickActionsLabel;
  final FocusNode? focusNode;

  bool _isComposing(TextEditingValue value) =>
      value.isComposingRangeValid && !value.composing.isCollapsed;

  bool _canSend(TextEditingValue value) =>
      enabled && !busy && value.text.trim().isNotEmpty && !_isComposing(value);

  void _submit() {
    if (_canSend(controller.value)) onSend();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (_isComposing(controller.value)) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (HardwareKeyboard.instance.isShiftPressed) {
      final value = controller.value;
      final range = value.selection.isValid
          ? TextRange(start: value.selection.start, end: value.selection.end)
          : TextRange.collapsed(value.text.length);
      controller.value = value.replaced(range, '\n').copyWith(
          selection: TextSelection.collapsed(offset: range.start + 1),
          composing: TextRange.empty);
    } else {
      _submit();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cards = BeeCardTheme.of(context);
    final hasQuickActions = quickActionsLabel != null;
    final surface = BeeSurface(
      padding: EdgeInsets.all(hasQuickActions ? 4 : 8),
      borderRadius: BorderRadius.circular(hasQuickActions ? 22 : 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (quickActionsLabel != null) ...[
          SizedBox.square(
            dimension: 44,
            child: BeeIconButton(
              key: const ValueKey('ai-chat-quick-actions'),
              label: quickActionsLabel!,
              icon: const BeeLineIcon('Plus', size: 20),
              onPressed: busy || !enabled ? null : onQuickActions,
            ),
          ),
          const SizedBox(width: 3),
        ],
        Expanded(
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: _handleKey,
            child: TextField(
              controller: controller,
              enabled: enabled,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onEditingComplete: () {},
              onSubmitted: (_) => _submit(),
              style: TextStyle(
                  color: scheme.onSurface, fontSize: 16, height: 1.25),
              decoration: InputDecoration(
                hintText: hint,
                hintMaxLines: 1,
                hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                isDense: true,
                filled: false,
                constraints:
                    BoxConstraints(minHeight: hasQuickActions ? 44 : 48),
                contentPadding: EdgeInsetsDirectional.fromSTEB(
                    quickActionsLabel == null ? 10 : 0, 12, 0, 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 3),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final active = busy || _canSend(value);
            return DecoratedBox(
              decoration: BoxDecoration(
                color: active ? scheme.primary : cards.soft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox.square(
                dimension: 44,
                child: BeeIconButton(
                  key: const ValueKey('ai-chat-send'),
                  label: busy ? stopLabel : sendLabel,
                  icon: Icon(
                    busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                    size: 22,
                    color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                  onPressed: busy
                      ? onStop
                      : active
                          ? _submit
                          : null,
                ),
              ),
            );
          },
        ),
      ]),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: hasQuickActions
            ? const EdgeInsets.fromLTRB(13, 9, 13, 12)
            : const EdgeInsets.fromLTRB(17, 8, 17, 12),
        child: hasQuickActions ? _FocusOutline(child: surface) : surface,
      ),
    );
  }
}

/// Keeps the ledger's skinned surface and its backdrop intact beneath the
/// composer outline. Keyboard focus can move between any of the three controls.
class _FocusOutline extends StatefulWidget {
  const _FocusOutline({required this.child});
  final Widget child;
  @override
  State<_FocusOutline> createState() => _FocusOutlineState();
}

class _FocusOutlineState extends State<_FocusOutline> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        onFocusChange: (value) => setState(() => _focused = value),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: _focused
                    ? Theme.of(context).colorScheme.primary
                    : BeeCardTheme.of(context).divider),
          ),
          child: widget.child,
        ),
      );
}
