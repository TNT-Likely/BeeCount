import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_business_ui/card_refinements.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../utils/app_localizations_resolver.dart';
import '../../../widgets/biz/bee_icon.dart';

class StartupLayoutSample extends StatefulWidget {
  const StartupLayoutSample({super.key});
  @override
  State<StartupLayoutSample> createState() => _StartupLayoutSampleState();
}

class _StartupLayoutSampleState extends State<StartupLayoutSample> {
  bool animate = false;
  int replay = 0;
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    final features = [
      BeeSplashSecurityFeature(
          title: l.splashSecurityLocalTitle,
          description: l.splashSecurityFeature1,
          icon: 'Database'),
      BeeSplashSecurityFeature(
          title: l.splashSecurityOpenTitle,
          description: l.splashSecurityFeature2,
          icon: 'Code'),
      BeeSplashSecurityFeature(
          title: l.splashSecuritySyncTitle,
          description: l.splashSecurityFeature3,
          icon: 'Cloud'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('启动业务组件只接收文案与品牌；不会启动真实预载或修改路由。',
          style: TextStyle(fontSize: 11)),
      const SizedBox(height: 12),
      BeeButton(
          label: animate ? '暂停启动动效' : '重播启动动效',
          kind: BeeButtonKind.secondary,
          onPressed: () => setState(() {
                animate = !animate;
                replay++;
              })),
      const SizedBox(height: 12),
      LayoutBuilder(
          builder: (ctx, box) => SizedBox(
              height: 568,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: MediaQuery(
                      data: MediaQuery.of(ctx).copyWith(
                          size: Size(box.maxWidth, 568),
                          padding: EdgeInsets.zero,
                          disableAnimations:
                              MediaQuery.disableAnimationsOf(ctx) ||
                                  !animate ||
                                  !TickerMode.of(ctx)),
                      child: ColoredBox(
                          color: BeeCardTheme.of(ctx).canvas,
                          child: BeeSplashLayout(
                              key: ValueKey(replay),
                              mark: BeeIcon(
                                  size: 72,
                                  color: Theme.of(ctx).colorScheme.primary),
                              appName: l.splashAppName,
                              slogan: l.splashSlogan,
                              initializing: l.splashInitializing,
                              preparing: l.splashPreparingRecords,
                              securitySummary: l.splashSecuritySummary,
                              securityCaption: l.splashSecurityCaption,
                              securityTitle: l.splashSecurityTitle,
                              securityFeatures: features,
                              securityFootnote: l.splashSecurityFootnote)))))),
      const SizedBox(height: 12),
      BeeSurface(
          child: BeeSplashSecurityContent(
              features: features, footnote: l.splashSecurityFootnote)),
    ]);
  }
}

class AssetToolbarSample extends StatefulWidget {
  const AssetToolbarSample({super.key});
  @override
  State<AssetToolbarSample> createState() => _AssetToolbarSampleState();
}

class _AssetToolbarSampleState extends State<AssetToolbarSample> {
  String value = 'all', event = '账户工具栏 · 受控筛选';
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BeeAssetAccountToolbar(
            items: const [
              BeeSegment('all', '全部'),
              BeeSegment('daily', '日常'),
              BeeSegment('valuation', '估值')
            ],
            value: value,
            onChanged: (v) => setState(() => value = v),
            searchLabel: '搜索账户示例',
            onSearch: () => setState(() => event = '点击搜索账户'),
            orderLabel: '排序账户示例',
            onOrder: () => setState(() => event = '点击账户排序')),
        Text(event, style: const TextStyle(fontSize: 11)),
      ]);
}

class SyncHealthSample extends StatefulWidget {
  const SyncHealthSample({super.key});
  @override
  State<SyncHealthSample> createState() => _SyncHealthSampleState();
}

class _SyncHealthSampleState extends State<SyncHealthSample> {
  bool animate = false;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile(
            title: const Text('播放检查中动效'),
            value: animate,
            onChanged: (v) => setState(() => animate = v)),
        for (final state in ['已同步', '检查中', '本地与云端有差异', '连接失败']) ...[
          TickerMode(
              enabled: animate && !MediaQuery.disableAnimationsOf(context),
              child: BeeSurface(
                  child: BeeSyncHealthHeader(
                      title: '云同步',
                      status: state,
                      busy: state == '检查中',
                      difference: state.contains('差异'),
                      error: state == '连接失败'))),
          const SizedBox(height: 10),
        ],
        const Text('四种受控状态同时展示；实际状态与重试继续由原云服务提供。',
            style: TextStyle(fontSize: 11)),
      ]);
}
