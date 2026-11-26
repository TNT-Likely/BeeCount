import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../skins/premium_skins.dart';

String skinPurchaseLabel(
    BuildContext context, PremiumSkins runtime, PremiumSkinCollection pack) {
  if (!runtime.salesEnabledForPack(pack.id)) {
    return skinText(context, '暂未开售', 'Not on sale yet');
  }
  final price = runtime.priceForPack(pack.id);
  if (price == null) {
    return skinText(context, '商店暂不可用', 'Store unavailable');
  }
  if (!runtime.canMakePayments) {
    return skinText(context, '当前设备限制内购', 'Purchases restricted');
  }
  return AppLocalizations.of(context).skinUnlockPack(pack.skins.length, price);
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
  const SkinStoreActions(
      {super.key, required this.pack, this.fromPreview = false});

  final PremiumSkinCollection pack;

  final bool fromPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 4,
      children: [
        for (final action in _StoreAction.values)
          TextButton(
            key: ValueKey(
                'official-${action.name}-${fromPreview ? 'preview' : pack.id}'),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                minimumSize: const Size(44, 44),
                visualDensity: VisualDensity.standard),
            onPressed: () => showBeeSheet<void>(context,
                title: action.label(context),
                child: _StoreActionBody(action, pack)),
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
  const _StoreActionBody(this.action, this.pack);

  final _StoreAction action;
  final PremiumSkinCollection pack;

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
    if (runtime.collections.isEmpty) {
      setState(() => status = _StoreStatus.unavailable);
      return;
    }
    setState(() => status = _StoreStatus.working);
    var result = _StoreStatus.unavailable;
    try {
      final completed =
          restoring ? await runtime.restore() : await runtime.redeem();
      if (completed) {
        final found = restoring
            ? runtime.collections.any((pack) => runtime.ownsPack(pack.id))
            : runtime.ownsPack(widget.pack.id);
        result = found ? _StoreStatus.success : _StoreStatus.missing;
      }
    } catch (_) {
      // The retry/fallback message below also covers native presentation errors.
    }
    if (mounted) setState(() => status = result);
  }

  String _message(BuildContext context, PremiumSkins runtime) {
    final l = AppLocalizations.of(context);
    final requested = widget.pack.nameOf(context);
    final separator =
        Localizations.localeOf(context).languageCode == 'zh' ? '、' : ', ';
    final owned = runtime.collections
        .where((pack) => runtime.ownsPack(pack.id))
        .map((pack) => pack.nameOf(context))
        .join(separator);
    return switch (status) {
      _StoreStatus.ready => l.skinRedeemDetails,
      _StoreStatus.working => restoring
          ? skinText(context, '正在查询当前 Apple 账户的购买记录…',
              'Checking purchases for this Apple Account…')
          : skinText(
              context, '正在等待 App Store 兑换结果…', 'Waiting for the App Store…'),
      _StoreStatus.success => restoring
          ? [
              if (owned.isNotEmpty) l.skinRestoreOwned(owned),
              if (!runtime.ownsPack(widget.pack.id))
                l.skinRestoreMissingPack(requested),
            ].join(' ')
          : skinText(context, '已验证合集权益，可选择皮肤使用。',
              'Collection access verified. Choose a skin to apply.'),
      _StoreStatus.missing => restoring
          ? l.skinRestoreMissingPack(requested)
          : skinText(context, '兑换成功后会同步权益，也可以从皮肤列表恢复购买。',
              'After redeeming, access syncs automatically or via Restore Purchases.'),
      _StoreStatus.unavailable => restoring
          ? skinText(context, '暂时无法恢复，请稍后重试。',
              'Could not restore purchases. Try again later.')
          : skinText(context, '可前往 App Store 的账户页兑换赠送码，再回来恢复购买。',
              'Redeem in the App Store account page, then return to restore purchases.'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(premiumSkinsProvider);
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
            child: Text(_message(context, runtime),
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
