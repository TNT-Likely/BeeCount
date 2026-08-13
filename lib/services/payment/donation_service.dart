import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import '../system/logger_service.dart';

/// 打赏服务
///
/// 负责管理iOS平台的IAP打赏功能
/// - 初始化IAP
/// - 查询商品信息
/// - 处理购买流程
/// - 监听购买状态
class DonationService {
  // 单例模式
  static final DonationService _instance = DonationService._internal();
  factory DonationService() => _instance;
  DonationService._internal();

  // StoreKit 平台实现是否已注册
  //
  // 本服务原先依赖 `in_app_purchase` 联合插件，由 `InAppPurchase.instance`
  // 按平台自动注册实现。为了不把 Google Play 结算库打进 Android 包
  // (Android 从来不显示打赏入口，见 pubspec.yaml 注释)，现在只依赖
  // iOS 专属的 `in_app_purchase_storekit`，注册需要自己做。
  // 必须保证幂等：重复 registerPlatform 会换掉实例，导致已有的
  // purchaseStream 订阅失效。
  static bool _storeKitRegistered = false;

  // IAP实例
  InAppPurchasePlatform get _iap {
    if (!_supported) {
      throw UnsupportedError('DonationService 仅支持 iOS/macOS');
    }
    if (!_storeKitRegistered) {
      InAppPurchaseStoreKitPlatform.registerPlatform();
      _storeKitRegistered = true;
    }
    return InAppPurchasePlatform.instance;
  }

  /// 当前平台是否支持打赏（仅 StoreKit 平台）
  static bool get _supported => Platform.isIOS || Platform.isMacOS;

  // 购买监听订阅
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // 事件流控制器
  final _successController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// 商品ID定义（仅用于查询，实际显示内容由 App Store 提供）
  static const Set<String> kProductIds = {
    'coffee_small',
    'coffee_medium',
    'coffee_large',
    'coffee_xlarge',
    'coffee_premium',
    'coffee_ultimate',
  };

  /// 模拟商品数据（仅用于开发和截图，生产环境会使用 App Store 的真实数据）
  static const Map<String, Map<String, String>> kMockProducts = {
    'coffee_small': {
      'title': '小杯咖啡',
      'price': '¥6',
      'description': '一杯咖啡的温暖支持',
    },
    'coffee_medium': {
      'title': '中杯咖啡',
      'price': '¥12',
      'description': '感谢您的慷慨支持',
    },
    'coffee_large': {
      'title': '大杯咖啡',
      'price': '¥38',
      'description': '您的支持让我倍感温暖',
    },
    'coffee_xlarge': {
      'title': '超大杯',
      'price': '¥68',
      'description': '非常感谢您的大力支持',
    },
    'coffee_premium': {
      'title': '尊享杯',
      'price': '¥128',
      'description': '感谢您的慷慨支持',
    },
    'coffee_ultimate': {
      'title': '至尊杯',
      'price': '¥348',
      'description': '感谢您的超级慷慨支持',
    },
  };

  /// 是否启用模拟数据（开发模式下自动启用）
  /// 注意：提交审核时必须设置为 false，使用真实 IAP 商品
  static const bool kUseMockData = false;

  /// 购买成功事件流
  Stream<String> get onSuccess => _successController.stream;

  /// 购买错误事件流
  Stream<String> get onError => _errorController.stream;

  /// 初始化IAP
  ///
  /// 返回: true=成功, false=失败
  Future<bool> initialize() async {
    try {
      // 仅支持iOS平台
      if (!_supported) {
        logger.info('Donation', 'Android平台暂不支持打赏功能');
        return false;
      }

      // 检查IAP是否可用
      final available = await _iap.isAvailable();
      if (!available) {
        logger.warning('Donation', 'IAP服务不可用');
        return false;
      }

      // 监听购买事件流
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () {
          logger.info('Donation', '购买流结束');
        },
        onError: (error) {
          logger.error('Donation', '购买流错误', error);
          _errorController.add('购买失败: $error');
        },
      );

      logger.info('Donation', 'IAP初始化成功');
      return true;
    } catch (e, stackTrace) {
      logger.error('Donation', 'IAP初始化失败', e, stackTrace);
      return false;
    }
  }

  /// 查询可用商品
  ///
  /// 返回: 商品列表
  Future<List<ProductDetails>> queryProducts() async {
    if (!_supported) {
      return [];
    }
    try {
      logger.info('Donation', '开始查询商品，Product IDs: $kProductIds');
      final response = await _iap.queryProductDetails(kProductIds);

      logger.info('Donation', '查询响应 - error: ${response.error}, notFoundIDs: ${response.notFoundIDs}, productDetails count: ${response.productDetails.length}');

      if (response.error != null) {
        logger.error('Donation', '查询商品失败 - error code: ${response.error!.code}, message: ${response.error!.message}, details: ${response.error!.details}');
        if (kUseMockData) {
          logger.info('Donation', '启用模拟数据模式');
          return _createMockProducts();
        }
        return [];
      }

      if (response.notFoundIDs.isNotEmpty) {
        logger.warning('Donation', '未找到以下商品 ID: ${response.notFoundIDs.join(", ")}');
      }

      // 如果查询到真实商品，优先使用真实商品
      if (response.productDetails.isNotEmpty) {
        logger.info('Donation', '查询到${response.productDetails.length}个真实商品:');
        for (final product in response.productDetails) {
          logger.info('Donation', '  - ${product.id}: ${product.title} (${product.price})');
        }
        return response.productDetails;
      }

      // 只有在没有查询到任何商品时才使用模拟数据
      if (kUseMockData) {
        logger.info('Donation', '所有商品未找到，启用模拟数据模式');
        return _createMockProducts();
      }

      logger.warning('Donation', '没有找到任何商品，且未启用模拟数据模式');
      return [];
    } catch (e, stackTrace) {
      logger.error('Donation', '查询商品异常', e, stackTrace);
      if (kUseMockData) {
        logger.info('Donation', '查询异常，启用模拟数据模式');
        return _createMockProducts();
      }
      return [];
    }
  }

  /// 创建模拟商品列表（仅用于开发和截图）
  List<ProductDetails> _createMockProducts() {
    return kProductIds.map((id) {
      final mockData = kMockProducts[id]!;
      return _MockProductDetails(
        id: id,
        title: mockData['title']!,
        description: mockData['description']!,
        price: mockData['price']!,
      );
    }).toList();
  }

  /// 发起打赏
  ///
  /// [product] 商品信息
  /// 返回: true=请求成功, false=请求失败
  Future<bool> donate(ProductDetails product) async {
    if (!_supported) {
      return false;
    }
    try {
      logger.info('Donation', '发起打赏: ${product.id}');

      final purchaseParam = PurchaseParam(productDetails: product);
      final success = await _iap.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: true,
      );

      if (!success) {
        logger.error('Donation', '发起购买请求失败');
        _errorController.add('购买请求失败');
      }

      return success;
    } catch (e, stackTrace) {
      logger.error('Donation', '发起打赏异常', e, stackTrace);
      _errorController.add('购买失败: $e');
      return false;
    }
  }

  /// 处理购买更新
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      logger.info('Donation', '购买状态更新: ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.purchased:
          // 购买成功
          await _handlePurchaseSuccess(purchase);
          break;

        case PurchaseStatus.error:
          // 购买失败
          final errorMsg = purchase.error?.message ?? '未知错误';
          logger.error('Donation', '购买失败: $errorMsg');
          _errorController.add('购买失败: $errorMsg');
          break;

        case PurchaseStatus.canceled:
          // 用户取消（无需提示）
          logger.info('Donation', '用户取消购买');
          _errorController.add(''); // 发送空消息以重置UI状态
          break;

        case PurchaseStatus.pending:
          // 待处理（等待确认）
          logger.info('Donation', '购买待处理');
          break;

        case PurchaseStatus.restored:
          // 恢复购买（消耗型商品不应出现）
          logger.warning('Donation', '消耗型商品出现恢复状态');
          break;
      }

      // 标记交易完成
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
        logger.info('Donation', '交易已完成: ${purchase.productID}');
      }
    }
  }

  /// 处理购买成功
  Future<void> _handlePurchaseSuccess(PurchaseDetails purchase) async {
    // 基础验证: 检查receipt是否存在
    final receipt = purchase.verificationData.serverVerificationData;

    if (receipt.isEmpty) {
      logger.warning('Donation', '购买凭证为空，可能是伪造购买');
      _errorController.add('购买验证失败');
      return;
    }

    // 检查receipt长度（正常的receipt通常很长）
    if (receipt.length < 100) {
      logger.warning('Donation', '购买凭证异常，长度过短: ${receipt.length}');
      _errorController.add('购买验证失败');
      return;
    }

    // 通过基础检查，购买成功
    final productId = purchase.productID;

    logger.info('Donation', '购买成功: $productId');
    _successController.add(productId);
  }

  /// 恢复购买（消耗型商品通常不需要）
  Future<void> restorePurchases() async {
    if (!_supported) {
      return;
    }
    try {
      logger.info('Donation', '开始恢复购买');
      await _iap.restorePurchases();
    } catch (e, stackTrace) {
      logger.error('Donation', '恢复购买失败', e, stackTrace);
      _errorController.add('恢复购买失败: $e');
    }
  }

  /// 释放资源
  void dispose() {
    logger.info('Donation', '释放DonationService资源');
    _subscription?.cancel();
    _successController.close();
    _errorController.close();
  }
}

/// 模拟商品详情（仅用于开发和截图）
class _MockProductDetails extends ProductDetails {
  _MockProductDetails({
    required String id,
    required String title,
    required String description,
    required String price,
  }) : super(
          id: id,
          title: title,
          description: description,
          price: price,
          rawPrice: 0.0,
          currencyCode: 'CNY',
        );
}
