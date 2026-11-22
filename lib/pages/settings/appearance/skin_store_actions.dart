import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../skins/premium_skins.dart';

bool canBuySkinPack(PremiumSkins runtime) =>
    runtime.skins.isNotEmpty &&
    !runtime.owned &&
    runtime.price != null &&
    runtime.canMakePayments &&
    runtime.salesEnabled &&
    !runtime.busy;

String skinPurchaseLabel(BuildContext context, PremiumSkins runtime) {
  if (!runtime.salesEnabled) {
    return skinText(context, '暂未开售', 'Not on sale yet');
  }
  final price = runtime.price;
  if (price == null) {
    return skinText(context, '商店暂不可用', 'Store unavailable');
  }
  if (!runtime.canMakePayments) {
    return skinText(context, '当前设备限制内购', 'Purchases restricted');
  }
  return skinText(context, '解锁 6 款 · $price', 'Unlock 6 skins · $price');
}

String skinPurchaseFeedback(
    BuildContext context, SkinPurchaseResult result, bool owned) {
  return switch (result) {
    SkinPurchaseResult.pending => skinText(context, '等待付款完成，稍后会自动更新',
        'Waiting for payment. Access updates automatically.'),
    SkinPurchaseResult.cancelled =>
      skinText(context, '已取消购买', 'Purchase cancelled.'),
    SkinPurchaseResult.launched => owned
        ? skinText(
            context, '已解锁，应用后即可使用这款皮肤。', 'Unlocked. Apply the skin when ready.')
        : skinText(context, '正在确认购买，可稍后恢复。',
            'Confirming the purchase. You can restore it later.'),
    _ => skinText(
        context, '商店暂不可用，请稍后重试。', 'The store is unavailable. Try again later.'),
  };
}

/// Both the collection heading and an unowned preview open the same actions.
class SkinStoreActions extends ConsumerWidget {
  const SkinStoreActions({super.key, this.fromPreview = false});

  final bool fromPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(premiumSkinsProvider);
    if (runtime.skins.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      children: [
        for (final action in _StoreAction.values)
          TextButton(
            key: ValueKey(
                'official-${action.name}${fromPreview ? '-preview' : ''}'),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                minimumSize: const Size(44, 44),
                visualDensity: VisualDensity.standard),
            onPressed: () => showBeeSheet<void>(context,
                title: action.label(context), child: _StoreActionBody(action)),
            child: Text(action.label(context),
                style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

enum _StoreAction {
  restore,
  redeem;

  String label(BuildContext context) => switch (this) {
        restore => skinText(context, '恢复购买', 'Restore purchases'),
        redeem => skinText(context, '兑换赠送码', 'Redeem an offer code'),
      };
}

enum _StoreStatus { ready, working, success, missing, unavailable }

class _StoreActionBody extends ConsumerStatefulWidget {
  const _StoreActionBody(this.action);

  final _StoreAction action;

  @override
  ConsumerState<_StoreActionBody> createState() => _StoreActionBodyState();
}

class _StoreActionBodyState extends ConsumerState<_StoreActionBody> {
  late var status = restoring ? _StoreStatus.working : _StoreStatus.ready;

  bool get restoring => widget.action == _StoreAction.restore;

  @override
  void initState() {
    super.initState();
    if (restoring) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run();
      });
    }
  }

  Future<void> _run() async {
    final runtime = ref.read(premiumSkinsProvider);
    if (runtime.skins.isEmpty) {
      setState(() => status = _StoreStatus.unavailable);
      return;
    }
    setState(() => status = _StoreStatus.working);
    var result = _StoreStatus.unavailable;
    try {
      final completed =
          restoring ? await runtime.restore() : await runtime.redeem();
      if (completed) {
        result = runtime.owned ? _StoreStatus.success : _StoreStatus.missing;
      }
    } catch (_) {
      // The retry/fallback message below also covers native presentation errors.
    }
    if (mounted) setState(() => status = result);
  }

  String _message(BuildContext context) => switch (status) {
        _StoreStatus.ready => skinText(
            context,
            '使用 App Store 的系统面板输入赠送码，验证通过后会解锁秋日手记。',
            'Enter the offer code in the App Store sheet to unlock Autumn Journal.'),
        _StoreStatus.working => restoring
            ? skinText(context, '正在查询当前 Apple 账户的购买记录…',
                'Checking purchases for this Apple Account…')
            : skinText(
                context, '正在等待 App Store 兑换结果…', 'Waiting for the App Store…'),
        _StoreStatus.success => restoring
            ? skinText(context, '已恢复购买，秋日手记的 6 款皮肤可用。',
                'Purchases restored. All six skins are available.')
            : skinText(context, '已验证合集权益，可选择皮肤使用。',
                'Collection access verified. Choose a skin to apply.'),
        _StoreStatus.missing => restoring
            ? skinText(context, '未找到购买记录。请用购买时的 Apple 账户重新查询。',
                'No purchase found. Try again with the purchasing Apple Account.')
            : skinText(context, '兑换成功后会同步权益，也可以从皮肤列表恢复购买。',
                'After redeeming, access syncs automatically or via Restore Purchases.'),
        _StoreStatus.unavailable => restoring
            ? skinText(context, '暂时无法恢复，请稍后重试。',
                'Could not restore purchases. Try again later.')
            : skinText(context, '可前往 App Store 的账户页兑换赠送码，再回来恢复购买。',
                'Redeem in the App Store account page, then return to restore purchases.'),
      };

  @override
  Widget build(BuildContext context) {
    final done = status == _StoreStatus.success ||
        (!restoring && status == _StoreStatus.missing);
    final label = done
        ? MaterialLocalizations.of(context).okButtonLabel
        : restoring
            ? skinText(context, '重新查询', 'Check again')
            : skinText(context, '打开 App Store 兑换', 'Open App Store redemption');
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status == _StoreStatus.working)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          Semantics(
            liveRegion: true,
            child: Text(_message(context),
                key: const ValueKey('official-store-message')),
          ),
          if (status != _StoreStatus.working) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: done ? () => Navigator.of(context).pop() : _run,
              child: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}
