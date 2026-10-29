import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// The host controls validation and the modal lifecycle; no account is contacted.
class TwoFactorChallengeSample extends StatefulWidget {
  const TwoFactorChallengeSample({super.key});
  @override
  State<TwoFactorChallengeSample> createState() => _TwoFactorChallengeState();
}

class _TwoFactorChallengeState extends State<TwoFactorChallengeSample> {
  String result = '合成邮箱，不请求云端验证';

  Future<void> open() async {
    final controller = TextEditingController();
    var method = 'totp', busy = false;
    String? error;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, update) {
              final code = controller.text.trim();
              return BeeTwoFactorChallengeDialog(
                  title: '双重验证示例',
                  email: 'qa@example.invalid',
                  method: method,
                  totpLabel: '验证码',
                  recoveryLabel: '恢复码',
                  totpHint: '6 位数字',
                  recoveryHint: '输入恢复码',
                  cancelLabel: '取消',
                  verifyLabel: '验证示例',
                  controller: controller,
                  hasRecovery: true,
                  verifying: busy,
                  canSubmit: !busy &&
                      (method == 'totp' ? code.length == 6 : code.isNotEmpty),
                  errorMessage: error,
                  onMethodChanged: (value) => update(() {
                        method = value;
                        controller.clear();
                        error = null;
                      }),
                  onCodeChanged: (_) => update(() => error = null),
                  onSubmit: () async {
                    update(() => busy = true);
                    await Future<void>.delayed(
                        const Duration(milliseconds: 300));
                    if (!ctx.mounted) return;
                    if (code == '000000') {
                      update(() {
                        busy = false;
                        error = '示例校验失败，请输入其他验证码';
                      });
                    } else {
                      Navigator.pop(ctx, true);
                    }
                  },
                  onCancel: () => Navigator.pop(ctx, false));
            }));
    // Keep the controller alive until the dialog's exit animation completes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (mounted) {
      setState(() => result = accepted == true ? '合成验证完成，无网络请求' : '已取消示例');
    }
  }

  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(result, key: const ValueKey('two-factor-sample-event')),
        const SizedBox(height: 8),
        BeeButton(label: '打开双重验证示例', onPressed: open),
      ]));
}

/// Reuses local product artwork; every external action is a controlled callback.
class PromotionComponentsSample extends StatefulWidget {
  const PromotionComponentsSample({super.key});
  @override
  State<PromotionComponentsSample> createState() => _PromotionComponentsState();
}

class _PromotionComponentsState extends State<PromotionComponentsSample> {
  static const info = BeePromotionData(
      logoAsset: 'assets/images/beeassets_logo.png',
      title: '产品推荐示例',
      subtitle: '本地素材 · 受控交互',
      introBody: '卡片、紧凑卡、介绍弹窗与图片浏览复用同一展示数据；链接操作由应用接入。',
      brandColor: Color(0xff3387d4),
      contactEmail: 'qa@example.invalid',
      screenshotAssets: [
        'assets/images/beeassets_dashboard.png',
        'assets/images/beeassets_holdings.png'
      ]);
  String event = '不会打开商店、邮件或网站';
  void record(String value) => setState(() => event = value);

  void screenshots(int index) => showDialog<void>(
      context: context,
      builder: (ctx) => BeePromotionGallery(
          assets: info.screenshotAssets,
          initialIndex: index,
          onClose: () => Navigator.pop(ctx)));

  void details() => showDialog<void>(
      context: context,
      builder: (ctx) => BeePromotionDialog(
          info: info,
          texts: const BeePromotionTexts(
              betaDialogTitle: '参与内测',
              betaDialogMessage: '这是展示示例',
              emailLabel: '联系邮箱',
              emailButton: '邮件联系',
              websiteButton: '前往官网',
              openStoreButton: '打开商店',
              testFlightButton: 'TestFlight'),
          hasStore: true,
          dualStore: false,
          onWebsite: () => record('官网回调已触发'),
          onEmail: () => record('邮件回调已触发'),
          onCopyEmail: () => record('复制邮箱回调已触发'),
          onScreenshot: screenshots,
          onStore: () => record('商店回调已触发')));

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(event, key: const ValueKey('promotion-sample-event')),
        const SizedBox(height: 8),
        BeePromotionCard(info: info, onOpen: details),
        const SizedBox(height: 10),
        BeePromotionCompact(info: info, onOpen: details),
        const SizedBox(height: 10),
        SizedBox(
            width: 100,
            height: 160,
            child: Align(
                alignment: Alignment.centerLeft,
                child: BeePromotionScreenshot(
                    asset: info.screenshotAssets.first,
                    onPressed: () => screenshots(0)))),
      ]);
}
