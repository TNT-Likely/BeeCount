import '../../data/repositories/base_repository.dart';
import '../../l10n/app_localizations.dart';
import '../system/logger_service.dart';

/// 预设标签服务
/// 用于生成系统默认标签
class TagSeedService {
  /// 预设标签颜色列表
  static const List<String> _defaultColors = [
    '#FF5722', // 深橙
    '#E91E63', // 粉红
    '#9C27B0', // 紫色
    '#673AB7', // 深紫
    '#3F51B5', // 靛蓝
    '#2196F3', // 蓝色
    '#03A9F4', // 浅蓝
    '#00BCD4', // 青色
    '#009688', // 蓝绿
    '#4CAF50', // 绿色
    '#8BC34A', // 浅绿
    '#CDDC39', // 酸橙
    '#FFC107', // 琥珀
    '#FF9800', // 橙色
    '#795548', // 棕色
    '#607D8B', // 蓝灰
    '#F44336', // 红色
    '#00E676', // 亮绿
    '#FF4081', // 粉红强调
    '#536DFE', // 靛蓝强调
  ];

  /// 获取预设标签定义
  /// 返回标签列表，包含名称和颜色
  static List<({String name, String? color})> getDefaultTags(
      AppLocalizations l10n) {
    return [
      // 常用商家类
      (name: l10n.tagDefaultMeituan, color: '#FF5722'),
      (name: l10n.tagDefaultEleme, color: '#2196F3'),
      (name: l10n.tagDefaultTaobao, color: '#FF9800'),
      (name: l10n.tagDefaultJD, color: '#F44336'),
      (name: l10n.tagDefaultPDD, color: '#E91E63'),
      (name: l10n.tagDefaultStarbucks, color: '#009688'),
      (name: l10n.tagDefaultLuckin, color: '#795548'),
      (name: l10n.tagDefaultMcDonalds, color: '#FFC107'),
      (name: l10n.tagDefaultKFC, color: '#D32F2F'),
      (name: l10n.tagDefaultHema, color: '#00BCD4'),
      (name: l10n.tagDefaultSams, color: '#3F51B5'),
      (name: l10n.tagDefaultCostco, color: '#673AB7'),

      // 场景类
      (name: l10n.tagDefaultBusinessTrip, color: '#607D8B'),
      (name: l10n.tagDefaultTravel, color: '#00E676'),
      (name: l10n.tagDefaultDining, color: '#FF4081'),
      (name: l10n.tagDefaultOnlineShopping, color: '#536DFE'),
      (name: l10n.tagDefaultDaily, color: '#8BC34A'),

      // 其他
      (name: l10n.tagDefaultReimbursement, color: '#9C27B0'),
      (name: l10n.tagDefaultRefundable, color: '#CDDC39'),
      (name: l10n.tagDefaultRefunded, color: '#4CAF50'),

      // 记账方式
      (name: l10n.tagDefaultVoiceBilling, color: '#FF9800'),
      (name: l10n.tagDefaultImageBilling, color: '#4CAF50'),
      (name: l10n.tagDefaultCameraBilling, color: '#2196F3'),
      (name: l10n.tagDefaultAiBilling, color: '#9C27B0'),
    ];
  }

  /// 生成默认标签
  /// 如果标签已存在（同名），则跳过
  /// 返回新创建的标签数量
  ///
  /// 走 `repo.createTag` 而不是直接 `db.into(db.tags).insert` —— 确保每个新
  /// 建标签都被 ChangeTracker 记进 sync_changes 日志。否则这批种子标签永远
  /// 不会被 push 到云端,web / 其他设备看不到(之前就是这个 bug)。
  static Future<int> seedDefaultTags(
    BaseRepository repo,
    AppLocalizations l10n,
  ) async {
    logger.info('TagSeedService', '开始生成默认标签');

    final defaultTags = getDefaultTags(l10n);
    int createdCount = 0;

    for (int i = 0; i < defaultTags.length; i++) {
      final tagDef = defaultTags[i];

      // 检查是否已存在同名标签 —— 复用 repo 的 query 接口,跨本地/云端实现一致。
      final existing = await repo.getTagByName(tagDef.name);
      if (existing != null) {
        logger.debug('TagSeedService', '标签已存在，跳过: ${tagDef.name}');
        continue;
      }

      await repo.createTag(
        name: tagDef.name,
        color: tagDef.color,
        sortOrder: i,
      );

      createdCount++;
      logger.debug('TagSeedService', '创建标签: ${tagDef.name}');
    }

    logger.info('TagSeedService', '默认标签生成完成，新建 $createdCount 个标签');
    return createdCount;
  }

  /// 获取随机颜色
  /// 用于用户手动创建标签时的默认颜色
  static String getRandomColor() {
    final index = DateTime.now().millisecondsSinceEpoch % _defaultColors.length;
    return _defaultColors[index];
  }

  /// 获取颜色列表
  /// 用于颜色选择器
  static List<String> getColorPalette() {
    return List.unmodifiable(_defaultColors);
  }

  /// 记账方式枚举
  static const String billingTypeVoice = 'voice';
  static const String billingTypeImage = 'image';
  static const String billingTypeCamera = 'camera';
  static const String billingTypeAi = 'ai';

  /// 获取记账方式对应的标签名称
  static String? getBillingTagName(String billingType, AppLocalizations l10n) {
    switch (billingType) {
      case billingTypeVoice:
        return l10n.tagDefaultVoiceBilling;
      case billingTypeImage:
        return l10n.tagDefaultImageBilling;
      case billingTypeCamera:
        return l10n.tagDefaultCameraBilling;
      case billingTypeAi:
        return l10n.tagDefaultAiBilling;
      default:
        return null;
    }
  }

  /// 获取记账方式对应的所有标签名称列表
  /// [billingTypes] 记账方式列表，如 ['image', 'ai'] 表示开启AI的图片记账
  static List<String> getBillingTagNames(
      List<String> billingTypes, AppLocalizations l10n) {
    final tagNames = <String>[];
    for (final type in billingTypes) {
      final tagName = getBillingTagName(type, l10n);
      if (tagName != null) {
        tagNames.add(tagName);
      }
    }
    return tagNames;
  }
}
