import 'dart:async';
import 'package:beecount_business_ui/support.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/payment/donation_service.dart';
import '../../../widgets/ui/ui.dart' show showToast;
import 'support_frame.dart';

final supportDonationProvider =
    Provider<SupportDonationGateway>((ref) => const SupportDonationGateway());

/// Native StoreKit behavior stays in the original service, never in pure UI.
class SupportDonationGateway {
  const SupportDonationGateway();
  Future<bool> initialize() => DonationService().initialize();
  Future<List<ProductDetails>> products() => DonationService().queryProducts();
  Stream<String> get success => DonationService().onSuccess;
  Stream<String> get error => DonationService().onError;
  Future<bool> donate(ProductDetails product) =>
      DonationService().donate(product);
}

class SupportDonationControls extends ConsumerStatefulWidget {
  const SupportDonationControls({super.key});
  @override
  ConsumerState<SupportDonationControls> createState() =>
      _SupportDonationControlsState();
}

class _SupportDonationControlsState
    extends ConsumerState<SupportDonationControls> {
  List<ProductDetails> products = [];
  bool loading = true;
  String? busy;
  StreamSubscription<String>? successSubscription, errorSubscription;
  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    successSubscription?.cancel();
    errorSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final gateway = ref.read(supportDonationProvider);
    try {
      if (!await gateway.initialize()) {
        if (mounted) setState(() => loading = false);
        return;
      }
      final result = await gateway.products();
      if (!mounted) return;
      setState(() {
        products = result;
        loading = false;
      });
      successSubscription = gateway.success.listen((id) {
        if (!mounted) return;
        setState(() => busy = null);
        final names = products.where((product) => product.id == id);
        final title = names.isNotEmpty
            ? names.first.title
            : products.isNotEmpty
                ? products.first.title
                : id;
        _thankYou(title);
      });
      errorSubscription = gateway.error.listen((error) {
        if (!mounted) return;
        setState(() => busy = null);
        if (error.isNotEmpty) showToast(context, error);
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _donate(String id) async {
    if (busy != null) return;
    final product = products.firstWhere((p) => p.id == id);
    setState(() => busy = id);
    try {
      final success = await ref.read(supportDonationProvider).donate(product);
      if (!success && mounted) setState(() => busy = null);
    } catch (_) {
      if (mounted) {
        setState(() => busy = null);
        showToast(context,
            AppLocalizations.of(context).donationPurchaseRequestFailed);
      }
    }
  }

  void _thankYou(String name) {
    final l = AppLocalizations.of(context);
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BeeDialog(
                showClose: false,
                title: Text(l.donationThankYouTitle),
                content: Text(l.donationThankYouMessage(name)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.commonConfirm))
                ]));
  }

  String _emoji(String id) {
    if (id.contains('small')) return '☕';
    if (id.contains('medium')) return '🥤';
    if (id.contains('large') && !id.contains('xlarge')) return '🍺';
    if (id.contains('xlarge')) return '🎉';
    if (id.contains('premium')) return '💎';
    if (id.contains('ultimate')) return '👑';
    return '☕';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final options = BeeDonationOptions(
        options: [
          for (final p in products)
            BeeDonationOption(
                id: p.id, title: p.title, price: p.price, emoji: _emoji(p.id))
        ],
        onDonate: _donate,
        loading: loading,
        emptyLabel: l.donationNoProducts,
        busyId: busy);
    return SupportFrame(
        title: l.donationTitle,
        subtitle: l.donationSubtitle,
        body: loading || products.isEmpty
            ? options
            : BeePageBody(eager: true, children: [
                BeeSupportText(
                    title: l.donationDescription,
                    description: l.donationDescriptionDetail,
                    icon: const BeeLineIcon('Heart'),
                    children: [
                      const SizedBox(height: 8),
                      Text(l.donationNoFeatures,
                          style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).hintColor))
                    ]),
                options
              ]));
  }
}
