import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/app_localizations.dart';

/// 账户分类：资产 vs 负债
enum AccountClassification { asset, liability }

/// 获取账户的资产/负债分类
AccountClassification getAccountClassification(String type) {
  if (isLiabilityType(type)) return AccountClassification.liability;
  return AccountClassification.asset;
}

/// 是否为资产类型
bool isAssetType(String type) => !isLiabilityType(type);

/// 是否为负债类型
bool isLiabilityType(String type) {
  return type == 'credit_card' || type == 'loan';
}

/// 估值账户类型（资产类）
const valuationOnlyAssetTypes = [
  'real_estate',
  'vehicle',
  'investment',
  'insurance',
  'social_fund',
];

/// 估值账户类型（负债类）
const valuationOnlyLiabilityTypes = ['loan'];

/// 所有估值账户类型
const valuationOnlyTypes = [
  ...valuationOnlyAssetTypes,
  ...valuationOnlyLiabilityTypes,
];

/// 是否为估值账户类型（不参与日常记账）
bool isValuationOnlyType(String type) => valuationOnlyTypes.contains(type);

/// 是否为可交易账户类型（参与日常记账）
bool isTradableType(String type) => !isValuationOnlyType(type);

/// 账户类型常量（完整排序）
const accountTypeOrder = [
  'cash',
  'bank_card',
  'credit_card',
  'alipay',
  'wechat',
  'other',
  'real_estate',
  'vehicle',
  'investment',
  'insurance',
  'social_fund',
  'loan',
];

/// 资产类型排序
const assetTypeOrder = [
  'cash',
  'bank_card',
  'alipay',
  'wechat',
  'other',
  'real_estate',
  'vehicle',
  'investment',
  'insurance',
  'social_fund',
];

/// 负债类型排序
const liabilityTypeOrder = ['credit_card', 'loan'];

/// 获取账户类型的 Material 图标（备用，用于无 SVG 的场景）
IconData getIconForAccountType(String type) {
  switch (type) {
    case 'cash':
      return Icons.payments_outlined;
    case 'bank_card':
      return Icons.credit_card;
    case 'credit_card':
      return Icons.credit_score;
    case 'alipay':
      return Icons.currency_yuan;
    case 'wechat':
      return Icons.chat;
    case 'investment':
      return Icons.trending_up;
    case 'loan':
      return Icons.house_outlined;
    case 'receivable':
      return Icons.call_received;
    case 'real_estate':
      return Icons.home_outlined;
    case 'vehicle':
      return Icons.directions_car_outlined;
    case 'insurance':
      return Icons.health_and_safety_outlined;
    case 'social_fund':
      return Icons.account_balance_outlined;
    case 'other':
      return Icons.account_balance_outlined;
    default:
      return Icons.account_balance_wallet_outlined;
  }
}

/// 获取账户类型名称
String getAccountTypeLabel(BuildContext context, String type) {
  final l10n = AppLocalizations.of(context);
  switch (type) {
    case 'cash':
      return l10n.accountTypeCash;
    case 'bank_card':
      return l10n.accountTypeBankCard;
    case 'credit_card':
      return l10n.accountTypeCreditCard;
    case 'alipay':
      return l10n.accountTypeAlipay;
    case 'wechat':
      return l10n.accountTypeWechat;
    case 'investment':
      return l10n.accountTypeInvestment;
    case 'loan':
      return l10n.accountTypeLoan;
    case 'receivable':
      return l10n.accountTypeReceivable;
    case 'real_estate':
      return l10n.accountTypeRealEstate;
    case 'vehicle':
      return l10n.accountTypeVehicle;
    case 'insurance':
      return l10n.accountTypeInsurance;
    case 'social_fund':
      return l10n.accountTypeSocialFund;
    case 'other':
      return l10n.accountTypeOther;
    default:
      return type;
  }
}

/// 获取账户类型的品牌颜色
Color getColorForAccountType(String type, Color primaryColor) {
  switch (type) {
    case 'alipay':
      return const Color(0xFF1677FF);
    case 'wechat':
      return const Color(0xFF07C160);
    case 'cash':
      return Colors.orange;
    case 'bank_card':
      return const Color(0xFF1890FF);
    case 'credit_card':
      return Colors.purple;
    case 'investment':
      return const Color(0xFFFF9800);
    case 'loan':
      return const Color(0xFFE91E63);
    case 'receivable':
      return const Color(0xFF009688);
    case 'real_estate':
      return const Color(0xFF795548);
    case 'vehicle':
      return const Color(0xFF607D8B);
    case 'insurance':
      return const Color(0xFF4CAF50);
    case 'social_fund':
      return const Color(0xFF3F51B5);
    default:
      return primaryColor;
  }
}

/// 获取 SVG 路径（所有类型均有彩色 SVG）
String _getSvgPath(String type) {
  switch (type) {
    case 'cash':
      return 'assets/icons/cash.svg';
    case 'bank_card':
      return 'assets/icons/bank_card.svg';
    case 'credit_card':
      return 'assets/icons/credit_card.svg';
    case 'alipay':
      return 'assets/icons/alipay.svg';
    case 'wechat':
      return 'assets/icons/wechat.svg';
    case 'investment':
      return 'assets/icons/investment.svg';
    case 'loan':
      return 'assets/icons/loan.svg';
    case 'receivable':
      return 'assets/icons/receivable.svg';
    case 'real_estate':
      return 'assets/icons/real_estate.svg';
    case 'vehicle':
      return 'assets/icons/vehicle.svg';
    case 'insurance':
      return 'assets/icons/insurance.svg';
    case 'social_fund':
      return 'assets/icons/social_fund.svg';
    case 'other':
      return 'assets/icons/other_account.svg';
    default:
      return 'assets/icons/other_account.svg';
  }
}

/// 统一的账户类型图标 Widget
/// 所有类型均使用彩色 SVG 图标
/// 设置 [monochrome] 为 true + [color] 可将图标渲染为单色（用于渐变卡片上的白色图标）
class AccountTypeIcon extends StatelessWidget {
  final String type;
  final double size;
  final Color? color;

  /// 是否以单色模式渲染（忽略 SVG 原始颜色，统一用 [color] 着色）
  final bool monochrome;

  const AccountTypeIcon({
    super.key,
    required this.type,
    this.size = 20,
    this.color,
    this.monochrome = false,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _getSvgPath(type),
      width: size,
      height: size,
      colorFilter: monochrome && color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
