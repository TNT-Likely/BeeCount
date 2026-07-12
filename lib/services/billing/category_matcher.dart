import '../../data/db.dart';

/// 智能分类匹配服务 - 根据商家名称或文本内容匹配分类
class CategoryMatcher {
  // 分类关键词映射
  static const Map<String, List<String>> _categoryKeywords = {
    // 餐饮
    '餐饮': [
      '餐厅',
      '饭店',
      '美食',
      '火锅',
      '烧烤',
      '小吃',
      '快餐',
      '外卖',
      '麦当劳',
      '肯德基',
      '星巴克',
      '瑞幸',
      '喜茶',
      '奈雪',
      '海底捞',
      '西贝',
      '必胜客',
      '汉堡王',
      '德克士',
      '饿了么',
      '美团外卖',
      '餐饮',
    ],

    // 交通
    '交通': [
      '地铁',
      '公交',
      '出租',
      '打车',
      '滴滴',
      '高德',
      '曹操',
      '加油',
      '停车',
      '过路费',
      '高速',
      'ETC',
      '火车票',
      '机票',
      '飞机票',
    ],

    // 购物
    '购物': [
      '淘宝',
      '天猫',
      '京东',
      '拼多多',
      '苏宁',
      '唯品会',
      '超市',
      '便利店',
      '7-11',
      '全家',
      '罗森',
      '商场',
      '百货',
    ],

    // 日用
    '日用': [
      '洗发水',
      '沐浴露',
      '牙膏',
      '毛巾',
      '纸巾',
      '日用品',
      '生活用品',
    ],

    // 娱乐
    '娱乐': [
      '电影',
      '影院',
      '万达',
      'KTV',
      '酒吧',
      '游戏',
      '网吧',
      '桌游',
      '剧本杀',
      '腾讯视频',
      '爱奇艺',
      '优酷',
      'Netflix',
    ],

    // 运动
    '运动': [
      '健身',
      '瑜伽',
      '游泳',
      '羽毛球',
      '篮球',
      '足球',
      '跑步',
      '健身房',
      '运动',
    ],

    // 医疗
    '医疗': [
      '医院',
      '药店',
      '诊所',
      '体检',
      '挂号',
      '药房',
      '医疗',
      '看病',
    ],

    // 教育
    '教育': [
      '学费',
      '培训',
      '课程',
      '书店',
      '教材',
      '教育',
      '学习',
      '考试',
    ],

    // 住房
    '住房': [
      '房租',
      '水费',
      '电费',
      '燃气费',
      '物业费',
      '维修',
      '装修',
    ],

    // 通讯
    '通讯': [
      '话费',
      '流量',
      '宽带',
      '中国移动',
      '中国联通',
      '中国电信',
      '手机费',
      '通讯',
    ],

    // 服饰
    '服饰': [
      '衣服',
      '鞋子',
      '裤子',
      '裙子',
      '外套',
      '优衣库',
      'ZARA',
      'H&M',
      '耐克',
      '阿迪达斯',
      '服装',
      '服饰',
    ],

    // 美容
    '美容': [
      '美容',
      '美发',
      '理发',
      '化妆品',
      '护肤品',
      '美甲',
      '按摩',
      'SPA',
    ],

    // 数码
    '数码': [
      '手机',
      '电脑',
      '平板',
      '相机',
      '耳机',
      '苹果',
      '华为',
      '小米',
      'OPPO',
      'vivo',
      '数码',
      '电子产品',
    ],
  };

  /// 根据文本匹配最合适的分类
  /// 返回匹配的分类ID,如果没有匹配则返回null
  static int? matchCategory(String text, List<Category> categories) {
    if (text.isEmpty || categories.isEmpty) return null;

    final textLower = text.toLowerCase();

    // 记录每个分类的匹配分数
    final scores = <int, int>{};

    for (final category in categories) {
      final categoryName = category.name;
      int score = 0;

      // 查找该分类的关键词列表
      final keywords = _categoryKeywords[categoryName] ?? [];

      // 遍历关键词,计算匹配分数
      for (final keyword in keywords) {
        if (textLower.contains(keyword.toLowerCase())) {
          // 完全匹配得2分,部分匹配得1分
          score += textLower == keyword.toLowerCase() ? 2 : 1;
        }
      }

      // 如果分类名称本身出现在文本中,额外加分
      if (textLower.contains(categoryName.toLowerCase())) {
        score += 3;
      }

      if (score > 0) {
        scores[category.id] = score;
      }
    }

    // 找出得分最高的分类
    if (scores.isEmpty) return null;

    final bestMatch =
        scores.entries.reduce((a, b) => a.value > b.value ? a : b);
    return bestMatch.key;
  }

  /// 根据商家名称匹配分类
  static int? matchByMerchant(String? merchant, List<Category> categories) {
    if (merchant == null || merchant.isEmpty) return null;
    return matchCategory(merchant, categories);
  }

  /// 根据完整的OCR文本匹配分类
  static int? matchByFullText(String fullText, List<Category> categories) {
    if (fullText.isEmpty) return null;
    return matchCategory(fullText, categories);
  }

  /// 综合匹配:先尝试商家名称,再尝试完整文本
  static int? smartMatch({
    String? merchant,
    required String fullText,
    required List<Category> categories,
  }) {
    // 优先使用商家名称匹配
    if (merchant != null && merchant.isNotEmpty) {
      final merchantMatch = matchByMerchant(merchant, categories);
      if (merchantMatch != null) return merchantMatch;
    }

    // 如果商家名称没有匹配到,使用完整文本
    return matchByFullText(fullText, categories);
  }
}
