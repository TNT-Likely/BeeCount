import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../services/payment/donation_service.dart';
import '../../services/system/logger_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../providers/theme_providers.dart';

/// 打赏页面
///
/// 展示打赏说明和商品列表，处理购买流程
class DonationPage extends ConsumerStatefulWidget {
  const DonationPage({super.key});

  @override
  ConsumerState<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends ConsumerState<DonationPage> {
  final _donationService = DonationService();
  List<ProductDetails> _products = [];
  bool _loading = true;
  bool _purchasing = false;
  String? _purchasingProductId;

  StreamSubscription<String>? _successSubscription;
  StreamSubscription<String>? _errorSubscription;

  @override
  void initState() {
    super.initState();
    _initDonation();
  }

  @override
  void dispose() {
    _successSubscription?.cancel();
    _errorSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDonation() async {
    setState(() => _loading = true);

    // 初始化IAP
    final initialized = await _donationService.initialize();
    if (!initialized) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    // 查询商品
    final products = await _donationService.queryProducts();
    if (mounted) {
      setState(() {
        _products = products;
        _loading = false;
      });
    }

    // 监听购买事件
    _successSubscription = _donationService.onSuccess.listen((productId) {
      if (mounted) {
        setState(() {
          _purchasing = false;
          _purchasingProductId = null;
        });
        // 从商品列表中查找对应商品的显示名称
        final product = _products.firstWhere(
          (p) => p.id == productId,
          orElse: () => _products.first,
        );
        _showThankYouDialog(product.title);
      }
    });

    _errorSubscription = _donationService.onError.listen((error) {
      if (mounted) {
        setState(() {
          _purchasing = false;
          _purchasingProductId = null;
        });
        // 只有非空错误消息才显示Toast（空消息表示用户取消）
        if (error.isNotEmpty) {
          showToast(context, error);
        }
      }
    });
  }

  Future<void> _handleDonate(ProductDetails product) async {
    if (_purchasing) {
      logger.warning('Donation', '正在购买中，请勿重复点击');
      return;
    }

    setState(() {
      _purchasing = true;
      _purchasingProductId = product.id;
    });

    final success = await _donationService.donate(product);
    if (!success && mounted) {
      setState(() {
        _purchasing = false;
        _purchasingProductId = null;
      });
    }
  }

  void _showThankYouDialog(String productName) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.favorite,
              color: Colors.red,
              size: 24.0.scaled(context, ref),
            ),
            SizedBox(width: 8.0.scaled(context, ref)),
            Text(l10n.donationThankYouTitle),
          ],
        ),
        content: Text(l10n.donationThankYouMessage(productName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.commonConfirm,
              style: TextStyle(
                color: ref.watch(primaryColorProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.donationTitle,
            subtitle: l10n.donationSubtitle,
            showBack: true,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 48.0.scaled(context, ref),
                              color: BeeTokens.iconSecondary(context),
                            ),
                            SizedBox(height: 16.0.scaled(context, ref)),
                            Text(
                              l10n.donationNoProducts,
                              style: TextStyle(
                                fontSize: 16.0.scaled(context, ref),
                                color: BeeTokens.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.0.scaled(context, ref),
                          vertical: 8.0.scaled(context, ref),
                        ),
                        children: [
                          // 说明卡片
                          SectionCard(
                            child: Padding(
                              padding:
                                  EdgeInsets.all(16.0.scaled(context, ref)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 20.0.scaled(context, ref),
                                        color: ref.watch(primaryColorProvider),
                                      ),
                                      SizedBox(width: 8.0.scaled(context, ref)),
                                      Text(
                                        l10n.donationDescription,
                                        style: TextStyle(
                                          fontSize: 16.0.scaled(context, ref),
                                          fontWeight: FontWeight.w600,
                                          color: BeeTokens.textPrimary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.0.scaled(context, ref)),
                                  Text(
                                    l10n.donationDescriptionDetail,
                                    style: TextStyle(
                                      fontSize: 14.0.scaled(context, ref),
                                      color: BeeTokens.textSecondary(context),
                                      height: 1.5,
                                    ),
                                  ),
                                  SizedBox(height: 8.0.scaled(context, ref)),
                                  Text(
                                    l10n.donationNoFeatures,
                                    style: TextStyle(
                                      fontSize: 13.0.scaled(context, ref),
                                      color: BeeTokens.textTertiary(context),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16.0.scaled(context, ref)),
                          // 商品列表
                          SectionCard(
                            child: Column(
                              children: _products.asMap().entries.map((entry) {
                                final index = entry.key;
                                final product = entry.value;
                                final isPurchasing = _purchasing &&
                                    _purchasingProductId == product.id;

                                return Column(
                                  children: [
                                    if (index > 0)
                                      BeeTokens.cardDivider(context),
                                    _ProductTile(
                                      product: product,
                                      isPurchasing: isPurchasing,
                                      onTap: () => _handleDonate(product),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                          SizedBox(height: 16.0.scaled(context, ref)),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

/// 商品列表项
class _ProductTile extends ConsumerWidget {
  final ProductDetails product;
  final bool isPurchasing;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.isPurchasing,
    required this.onTap,
  });

  String _getProductEmoji(String productId) {
    if (productId.contains('small')) return '☕';
    if (productId.contains('medium')) return '🥤';
    if (productId.contains('large') && !productId.contains('xlarge'))
      return '🍺';
    if (productId.contains('xlarge')) return '🎉';
    if (productId.contains('premium')) return '💎';
    if (productId.contains('ultimate')) return '👑';
    return '☕';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emoji = _getProductEmoji(product.id);
    final primaryColor = ref.watch(primaryColorProvider);

    return InkWell(
      onTap: isPurchasing ? null : onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16.0.scaled(context, ref),
          vertical: 12.0.scaled(context, ref),
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 48.0.scaled(context, ref),
              height: 48.0.scaled(context, ref),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.0.scaled(context, ref)),
              ),
              alignment: Alignment.center,
              child: Text(
                emoji,
                style: TextStyle(fontSize: 24.0.scaled(context, ref)),
              ),
            ),
            SizedBox(width: 12.0.scaled(context, ref)),
            // 标题
            Expanded(
              child: Text(
                product.title,
                style: TextStyle(
                  fontSize: 16.0.scaled(context, ref),
                  fontWeight: FontWeight.w500,
                  color: BeeTokens.textPrimary(context),
                ),
              ),
            ),
            // 购买按钮
            if (isPurchasing)
              SizedBox(
                width: 80.0.scaled(context, ref),
                height: 36.0.scaled(context, ref),
                child: Center(
                  child: SizedBox(
                    width: 20.0.scaled(context, ref),
                    height: 20.0.scaled(context, ref),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.0.scaled(context, ref),
                  vertical: 8.0.scaled(context, ref),
                ),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(8.0.scaled(context, ref)),
                ),
                child: Text(
                  product.price,
                  style: TextStyle(
                    fontSize: 15.0.scaled(context, ref),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
