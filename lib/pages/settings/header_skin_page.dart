import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/theme_providers.dart';
import '../../styles/header_skins.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/ui.dart';

/// 头部皮肤选择。顶部「亮色 / 暗黑」切换:亮色编辑「头部皮肤」,暗黑编辑「暗黑头部皮肤」;
/// 预览也按所选模式渲染(暗黑用黑底,正好看图案皮肤真实效果)。
///
/// 渲染优先级(见 PrimaryHeader):亮色 → 头部皮肤;暗色 → 优先暗黑皮肤,未单独设置则
/// 回退到头部皮肤。所以暗黑那栏选「跟随头部皮肤」即代表两个模式共用一款。
class HeaderSkinPage extends ConsumerStatefulWidget {
  const HeaderSkinPage({super.key});

  @override
  ConsumerState<HeaderSkinPage> createState() => _HeaderSkinPageState();
}

class _HeaderSkinPageState extends ConsumerState<HeaderSkinPage> {
  bool? _editDark; // null = 默认跟随当前系统模式

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    final modeIsDark = BeeTokens.isDark(context);
    final editDark = _editDark ?? modeIsDark;

    final current = editDark
        ? ref.watch(headerSkinDarkProvider)
        : ref.watch(headerSkinProvider);

    // none:亮色 = 纯色;暗黑 = 跟随头部皮肤。其余皮肤按编辑模式渲染预览。
    final items = <({String id, String name, Widget preview})>[
      (
        id: kHeaderSkinNone,
        name: editDark ? l10n.headerSkinFollow : l10n.headerSkinNone,
        preview: ColoredBox(color: editDark ? Colors.black : primary),
      ),
      for (final s in kHeaderSkins)
        (id: s.id, name: s.nameOf(l10n), preview: s.builder(primary, editDark)),
    ];

    void select(String id) {
      if (editDark) {
        ref.read(headerSkinDarkProvider.notifier).state = id;
      } else {
        ref.read(headerSkinProvider.notifier).state = id;
      }
    }

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.headerSkinTitle,
            subtitle: l10n.headerSkinSubtitle,
            showBack: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.headerSkinModeLight),
                    icon: const Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.headerSkinModeDark),
                    icon: const Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {editDark},
                onSelectionChanged: (s) => setState(() => _editDark = s.first),
              ),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.95,
              children: [
                for (final it in items)
                  _SkinCard(
                    name: it.name,
                    preview: it.preview,
                    selected: it.id == current,
                    primary: primary,
                    onTap: () => select(it.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.name,
    required this.preview,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  final String name;
  final Widget preview;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? primary : BeeTokens.border(context),
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    preview,
                    if (selected)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration:
                              BoxDecoration(color: primary, shape: BoxShape.circle),
                          child:
                              const Icon(Icons.check, size: 14, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? primary : BeeTokens.textPrimary(context),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
