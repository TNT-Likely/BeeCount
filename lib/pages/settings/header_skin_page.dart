import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/theme_providers.dart';
import '../../styles/header_skins.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/ui.dart';

/// 头部皮肤选择。所有皮肤亮暗通用(亮=主题色底 + 白/渐变图形;暗=纯黑底 + 偏淡的
/// 主题色图形),预览按当前系统模式渲染。
class HeaderSkinPage extends ConsumerWidget {
  const HeaderSkinPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    final current = ref.watch(headerSkinProvider);
    final modeIsDark = BeeTokens.isDark(context);

    // 预览底色与真实 header 基础色一致:亮=主题色,暗=纯黑。图案皮肤是透明叠加,
    // 必须垫底色才看得见。
    final base = modeIsDark ? Colors.black : primary;

    final items = <({String id, String name, Widget preview})>[
      (
        id: kHeaderSkinNone,
        name: l10n.headerSkinNone,
        preview: ColoredBox(color: base),
      ),
      for (final s in kHeaderSkins)
        (
          id: s.id,
          name: s.nameOf(l10n),
          preview:
              ColoredBox(color: base, child: s.builder(primary, modeIsDark)),
        ),
    ];

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.headerSkinTitle,
            subtitle: l10n.headerSkinSubtitle,
            showBack: true,
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
                    onTap: () =>
                        ref.read(headerSkinProvider.notifier).state = it.id,
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
