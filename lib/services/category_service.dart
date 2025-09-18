import 'package:flutter/material.dart';

/// 分类服务类，统一管理默认分类和图标映射
class CategoryService {
  CategoryService._();

  /// 默认支出分类列表 (按优先级排序)
  static const List<String> defaultExpenseCategories = [
    '餐饮', '交通', '购物', '娱乐', '居家', '家庭', '通讯', '水电', '住房', '医疗', '教育',
    '宠物', '运动', '数码', '旅行', '烟酒', '母婴', '美容', '维修', '社交',
    '学习', '汽车', '打车', '地铁', '外卖', '物业', '停车', '捐赠', '礼金', '纳税',
    '饮料', '服装', '零食', '红包', '水果', '游戏', '书', '爱人', '装修', '日用品',
    '彩票', '股票', '社保', '快递', '工作'
  ];

  /// 默认收入分类列表 (按优先级排序)
  static const List<String> defaultIncomeCategories = [
    '工资', '理财', '红包', '奖金', '报销', '兼职', '礼金', '利息', '退款', '投资', '二手转卖',
    '社会保障', '退税退费', '公积金'
  ];

  /// 判断是否为默认分类
  static bool isDefaultCategory(String name, String kind) {
    if (kind == 'expense') {
      return defaultExpenseCategories.contains(name);
    } else {
      return defaultIncomeCategories.contains(name);
    }
  }

  /// 获取默认分类的排序权重 (越小越靠前)
  static int getDefaultCategoryWeight(String name, String kind) {
    if (kind == 'expense') {
      final index = defaultExpenseCategories.indexOf(name);
      return index >= 0 ? index : 999;
    } else {
      final index = defaultIncomeCategories.indexOf(name);
      return index >= 0 ? index : 999;
    }
  }

  /// 获取默认分类名称集合
  static Set<String> getDefaultCategoryNames(String kind) {
    if (kind == 'expense') {
      return defaultExpenseCategories.toSet();
    } else {
      return defaultIncomeCategories.toSet();
    }
  }

  /// 获取默认分类的图标名称
  static String getDefaultCategoryIcon(String categoryName, String kind) {
    if (kind == 'expense') {
      switch (categoryName) {
        case '餐饮': return 'restaurant';
        case '交通': return 'directions_car';
        case '购物': return 'shopping_cart';
        case '娱乐': return 'movie';
        case '居家': return 'home';
        case '家庭': return 'family_restroom';
        case '通讯': return 'phone';
        case '水电': return 'flash_on';
        case '住房': return 'home_work';
        case '医疗': return 'local_hospital';
        case '教育': return 'school';
        case '宠物': return 'pets';
        case '运动': return 'fitness_center';
        case '数码': return 'smartphone';
        case '旅行': return 'flight';
        case '烟酒': return 'local_bar';
        case '母婴': return 'child_care';
        case '美容': return 'face';
        case '维修': return 'handyman';
        case '社交': return 'group';
        case '学习': return 'school';
        case '汽车': return 'directions_car';
        case '打车': return 'local_taxi';
        case '地铁': return 'directions_subway';
        case '外卖': return 'delivery_dining';
        case '物业': return 'apartment';
        case '停车': return 'local_parking';
        case '捐赠': return 'volunteer_activism';
        case '礼金': return 'card_giftcard';
        case '纳税': return 'receipt_long';
        case '饮料': return 'local_cafe';
        case '服装': return 'checkroom';
        case '零食': return 'fastfood';
        case '红包': return 'wallet';
        case '水果': return 'eco';
        case '游戏': return 'sports_esports';
        case '书': return 'menu_book';
        case '爱人': return 'favorite';
        case '装修': return 'home_repair_service';
        case '日用品': return 'local_laundry_service';
        case '彩票': return 'confirmation_number';
        case '股票': return 'trending_up';
        case '社保': return 'security';
        case '快递': return 'local_shipping';
        case '工作': return 'work_outline';
        default: return 'category';
      }
    } else {
      switch (categoryName) {
        case '工资': return 'work';
        case '理财': return 'account_balance';
        case '红包': return 'card_giftcard';
        case '奖金': return 'emoji_events';
        case '报销': return 'receipt';
        case '兼职': return 'schedule';
        case '礼金': return 'card_giftcard';
        case '利息': return 'monetization_on';
        case '退款': return 'undo';
        case '投资': return 'trending_up';
        case '二手转卖': return 'sell';
        case '社会保障': return 'health_and_safety';
        case '退税退费': return 'receipt_long';
        case '公积金': return 'account_balance_wallet';
        default: return 'attach_money';
      }
    }
  }

  /// 根据分类名称智能推导图标 (用于动态分类名称匹配)
  static IconData getCategoryIconByName(String categoryName) {
    // 首先检查是否为默认分类，如果是则使用默认图标
    if (defaultExpenseCategories.contains(categoryName)) {
      final iconName = getDefaultCategoryIcon(categoryName, 'expense');
      return getCategoryIcon(iconName);
    }
    if (defaultIncomeCategories.contains(categoryName)) {
      final iconName = getDefaultCategoryIcon(categoryName, 'income');
      return getCategoryIcon(iconName);
    }

    // 否则使用模糊匹配逻辑
    final n = categoryName;
    if (n.contains('餐') ||
        n.contains('饭') ||
        n.contains('吃') ||
        n.contains('外卖')) {
      return Icons.restaurant_outlined;
    }
    if (n.contains('打车')) return Icons.local_taxi_outlined;
    if (n.contains('地铁')) return Icons.subway_outlined;
    if (n.contains('公交')) return Icons.directions_bus_outlined;
    if (n.contains('高铁') || n.contains('火车')) return Icons.train_outlined;
    if (n.contains('飞机')) return Icons.flight_outlined;
    if (n.contains('交通') || n.contains('出行')) {
      return Icons.directions_transit_outlined;
    }
    // 车辆相关（未被上面交通覆盖的"车/车辆/车贷/购车/爱车"）
    if (n == '车' ||
        n.contains('车辆') ||
        n.contains('车贷') ||
        n.contains('购车') ||
        n.contains('爱车')) {
      return Icons.directions_car_outlined;
    }
    if (n.contains('购物') ||
        n.contains('百货') ||
        n.contains('网购') ||
        n.contains('淘宝') ||
        n.contains('京东')) {
      return Icons.shopping_bag_outlined;
    }
    if (n.contains('社交') ||
        n.contains('聚会') ||
        n.contains('朋友') ||
        n.contains('聚餐')) {
      return Icons.groups_outlined;
    }
    if (n.contains('服饰') ||
        n.contains('衣') ||
        n.contains('鞋') ||
        n.contains('裤') ||
        n.contains('帽')) {
      return Icons.checkroom_outlined;
    }
    if (n.contains('超市') ||
        n.contains('生鲜') ||
        n.contains('菜') ||
        n.contains('粮油') ||
        n.contains('蔬菜') ||
        n.contains('水果')) {
      return Icons.local_grocery_store_outlined;
    }
    if (n.contains('娱乐') ||
        n.contains('游戏') ||
        n.contains('电影') ||
        n.contains('影院')) {
      return Icons.sports_esports_outlined;
    }
    if (n.contains('家庭') ||
        n.contains('家人') ||
        n.contains('家属')) {
      return Icons.family_restroom_outlined;
    }
    if (n.contains('居家') ||
        n.contains('家') ||
        n.contains('家居') ||
        n.contains('物业') ||
        n.contains('维修')) {
      return Icons.chair_outlined;
    }
    if (n.contains('美妆') ||
        n.contains('化妆') ||
        n.contains('护肤') ||
        n.contains('美容')) {
      return Icons.brush_outlined;
    }
    if (n.contains('通讯') ||
        n.contains('话费') ||
        n.contains('宽带') ||
        n.contains('流量')) {
      return Icons.network_cell_outlined;
    }
    if (n.contains('订阅') || n.contains('会员') || n.contains('流媒体')) {
      return Icons.subscriptions_outlined;
    }
    if (n.contains('礼物') ||
        n.contains('红包') ||
        n.contains('礼金') ||
        n.contains('请客') ||
        n.contains('人情')) {
      return Icons.card_giftcard_outlined;
    }
    if (n.contains('水') || n.contains('电') || n.contains('煤') || n.contains('燃气')) {
      return Icons.water_drop_outlined;
    }
    if (n.contains('房贷') ||
        n.contains('按揭') ||
        n.contains('贷款') ||
        n.contains('信用卡')) {
      return Icons.account_balance_outlined;
    }
    if (n.contains('住房') ||
        n.contains('房租') ||
        n.contains('房') ||
        n.contains('租')) {
      return Icons.home_outlined;
    }
    if (n.contains('工资') ||
        n.contains('收入') ||
        n.contains('奖金') ||
        n.contains('报销') ||
        n.contains('兼职') ||
        n.contains('转账')) {
      return Icons.attach_money_outlined;
    }
    if (n.contains('理财') ||
        n.contains('利息') ||
        n.contains('基金') ||
        n.contains('股票') ||
        n.contains('退款')) {
      return Icons.savings_outlined;
    }
    if (n.contains('教育') ||
        n.contains('学习') ||
        n.contains('培训') ||
        n.contains('书')) {
      return Icons.menu_book_outlined;
    }
    if (n.contains('医疗') ||
        n.contains('医院') ||
        n.contains('药') ||
        n.contains('体检')) {
      return Icons.medical_services_outlined;
    }
    if (n.contains('宠物') || n.contains('猫') || n.contains('狗')) {
      return Icons.pets_outlined;
    }
    if (n.contains('运动') ||
        n.contains('健身') ||
        n.contains('球') ||
        n.contains('跑步')) {
      return Icons.fitness_center_outlined;
    }
    if (n.contains('数码') ||
        n.contains('电子') ||
        n.contains('手机') ||
        n.contains('电脑')) {
      return Icons.devices_other_outlined;
    }
    if (n.contains('旅行') ||
        n.contains('旅游') ||
        n.contains('出差') ||
        n.contains('机票')) {
      return Icons.card_travel_outlined;
    }
    if (n.contains('酒店') || n.contains('住宿') || n.contains('民宿')) {
      return Icons.hotel_outlined;
    }
    if (n.contains('烟') || n.contains('酒') || n.contains('茶')) {
      return Icons.local_bar_outlined;
    }
    if (n.contains('母婴') || n.contains('孩子') || n.contains('奶粉')) {
      return Icons.child_friendly_outlined;
    }
    if (n.contains('停车')) return Icons.local_parking;
    if (n.contains('加油')) return Icons.local_gas_station_outlined;
    if (n.contains('保养') || n.contains('维修')) return Icons.build_outlined;
    if (n.contains('汽车') || n.contains('车辆') || n == '车') {
      return Icons.directions_car_outlined;
    }
    if (n.contains('过路费') || n.contains('过桥费')) return Icons.alt_route_outlined;
    if (n.contains('快递') || n.contains('邮寄')) {
      return Icons.local_shipping_outlined;
    }
    if (n.contains('税') ||
        n.contains('社保') ||
        n.contains('公积金') ||
        n.contains('罚款')) {
      return Icons.receipt_long_outlined;
    }
    if (n.contains('捐赠') || n.contains('公益')) {
      return Icons.volunteer_activism_outlined;
    }
    if (n.contains('工作') ||
        n.contains('办公') ||
        n.contains('出差') ||
        n.contains('职场') ||
        n.contains('会议')) {
      return Icons.work_outline;
    }
    return Icons.circle_outlined;
  }

  /// 获取分类图标
  static IconData getCategoryIcon(String? iconName) {
    if (iconName == null || iconName.isEmpty) {
      return Icons.category;
    }

    // 将图标名称映射到实际的图标
    switch (iconName) {
      // 基础
      case 'category': return Icons.category;
      case 'label': return Icons.label;
      case 'bookmark': return Icons.bookmark;
      case 'star': return Icons.star;
      case 'favorite': return Icons.favorite;
      case 'circle': return Icons.circle;

      // 餐饮美食
      case 'restaurant': return Icons.restaurant;
      case 'local_dining': return Icons.local_dining;
      case 'fastfood': return Icons.fastfood;
      case 'local_cafe': return Icons.local_cafe;
      case 'local_bar': return Icons.local_bar;
      case 'local_pizza': return Icons.local_pizza;
      case 'cake': return Icons.cake;
      case 'coffee': return Icons.coffee;
      case 'breakfast_dining': return Icons.breakfast_dining;
      case 'lunch_dining': return Icons.lunch_dining;
      case 'dinner_dining': return Icons.dinner_dining;
      case 'icecream': return Icons.icecream;
      case 'bakery_dining': return Icons.bakery_dining;
      case 'liquor': return Icons.liquor;
      case 'wine_bar': return Icons.wine_bar;
      case 'restaurant_menu': return Icons.restaurant_menu;
      case 'set_meal': return Icons.set_meal;
      case 'ramen_dining': return Icons.ramen_dining;
      case 'delivery_dining': return Icons.delivery_dining;

      // 交通出行
      case 'directions_car': return Icons.directions_car;
      case 'directions_bus': return Icons.directions_bus;
      case 'directions_subway': return Icons.directions_subway;
      case 'local_taxi': return Icons.local_taxi;
      case 'flight': return Icons.flight;
      case 'train': return Icons.train;
      case 'motorcycle': return Icons.motorcycle;
      case 'directions_bike': return Icons.directions_bike;
      case 'directions_walk': return Icons.directions_walk;
      case 'boat': return Icons.directions_boat;
      case 'electric_scooter': return Icons.electric_scooter;
      case 'local_gas_station': return Icons.local_gas_station;
      case 'local_parking': return Icons.local_parking;
      case 'local_shipping': return Icons.local_shipping;
      case 'traffic': return Icons.traffic;
      case 'directions_railway': return Icons.directions_railway;
      case 'airport_shuttle': return Icons.airport_shuttle;
      case 'pedal_bike': return Icons.pedal_bike;
      case 'car_rental': return Icons.car_rental;

      // 购物消费
      case 'shopping_cart': return Icons.shopping_cart;
      case 'shopping_bag': return Icons.shopping_bag;
      case 'store': return Icons.store;
      case 'local_mall': return Icons.local_mall;
      case 'local_grocery_store': return Icons.local_grocery_store;
      case 'storefront': return Icons.storefront;
      case 'shopping_basket': return Icons.shopping_basket;
      case 'local_offer': return Icons.local_offer;
      case 'receipt': return Icons.receipt;
      case 'sell': return Icons.sell;
      case 'price_check': return Icons.price_check;
      case 'card_giftcard': return Icons.card_giftcard;
      case 'redeem': return Icons.redeem;
      case 'inventory': return Icons.inventory;
      case 'add_shopping_cart': return Icons.add_shopping_cart;
      case 'loyalty': return Icons.loyalty;

      // 居住生活
      case 'home': return Icons.home;
      case 'house': return Icons.house;
      case 'family_restroom': return Icons.family_restroom;
      case 'apartment': return Icons.apartment;
      case 'cleaning_services': return Icons.cleaning_services;
      case 'plumbing': return Icons.plumbing;
      case 'electrical_services': return Icons.electrical_services;
      case 'flash_on': return Icons.flash_on;
      case 'water_drop': return Icons.water_drop;
      case 'air': return Icons.air;
      case 'kitchen': return Icons.kitchen;
      case 'bathtub': return Icons.bathtub;
      case 'bed': return Icons.bed;
      case 'chair': return Icons.chair;
      case 'table_restaurant': return Icons.table_restaurant;
      case 'lightbulb': return Icons.lightbulb;
      case 'hvac': return Icons.hvac;
      case 'roofing': return Icons.roofing;
      case 'foundation': return Icons.foundation;
      case 'home_work': return Icons.home_work;
      case 'home_repair_service': return Icons.home_repair_service;

      // 通讯设备
      case 'phone': return Icons.phone;
      case 'smartphone': return Icons.smartphone;
      case 'phone_android': return Icons.phone_android;
      case 'phone_iphone': return Icons.phone_iphone;
      case 'tablet': return Icons.tablet;
      case 'laptop': return Icons.laptop;
      case 'computer': return Icons.computer;
      case 'desktop_windows': return Icons.desktop_windows;
      case 'watch': return Icons.watch;
      case 'headphones': return Icons.headphones;
      case 'headset': return Icons.headset;
      case 'keyboard': return Icons.keyboard;
      case 'mouse': return Icons.mouse;
      case 'wifi': return Icons.wifi;
      case 'router': return Icons.router;
      case 'cable': return Icons.cable;

      // 娱乐休闲
      case 'movie': return Icons.movie;
      case 'music_note': return Icons.music_note;
      case 'sports_esports': return Icons.sports_esports;
      case 'theater_comedy': return Icons.theater_comedy;
      case 'casino': return Icons.casino;
      case 'celebration': return Icons.celebration;
      case 'party_mode': return Icons.party_mode;
      case 'nightlife': return Icons.nightlife;
      case 'local_activity': return Icons.local_activity;
      case 'attractions': return Icons.attractions;
      case 'beach_access': return Icons.beach_access;
      case 'pool': return Icons.pool;
      case 'spa': return Icons.spa;
      case 'games': return Icons.games;
      case 'sports': return Icons.sports;
      case 'sports_soccer': return Icons.sports_soccer;
      case 'sports_basketball': return Icons.sports_basketball;
      case 'sports_tennis': return Icons.sports_tennis;
      case 'group': return Icons.group;

      // 健康医疗
      case 'local_hospital': return Icons.local_hospital;
      case 'medical_services': return Icons.medical_services;
      case 'local_pharmacy': return Icons.local_pharmacy;
      case 'health_and_safety': return Icons.health_and_safety;
      case 'medication': return Icons.medication;
      case 'fitness_center': return Icons.fitness_center;
      case 'self_improvement': return Icons.self_improvement;
      case 'psychology': return Icons.psychology;
      case 'healing': return Icons.healing;
      case 'monitor_heart': return Icons.monitor_heart;
      case 'elderly': return Icons.elderly;
      case 'accessible': return Icons.accessible;
      case 'medical_information': return Icons.medical_information;
      case 'biotech': return Icons.biotech;
      case 'coronavirus': return Icons.coronavirus;
      case 'vaccines': return Icons.vaccines;
      case 'child_care': return Icons.child_care;

      // 教育学习
      case 'school': return Icons.school;
      case 'book': return Icons.book;
      case 'library_books': return Icons.library_books;
      case 'menu_book': return Icons.menu_book;
      case 'auto_stories': return Icons.auto_stories;
      case 'edit': return Icons.edit;
      case 'create': return Icons.create;
      case 'calculate': return Icons.calculate;
      case 'science': return Icons.science;
      case 'brush': return Icons.brush;
      case 'palette': return Icons.palette;
      case 'music_video': return Icons.music_video;
      case 'piano': return Icons.piano;
      case 'translate': return Icons.translate;
      case 'language': return Icons.language;
      case 'quiz': return Icons.quiz;

      // 宠物动物
      case 'pets': return Icons.pets;
      case 'cruelty_free': return Icons.cruelty_free;
      case 'bug_report': return Icons.bug_report;
      case 'emoji_nature': return Icons.emoji_nature;
      case 'park': return Icons.park;
      case 'grass': return Icons.grass;
      case 'forest': return Icons.forest;
      case 'agriculture': return Icons.agriculture;
      case 'eco': return Icons.eco;
      case 'local_florist': return Icons.local_florist;
      case 'yard': return Icons.yard;

      // 服装美容
      case 'checkroom': return Icons.checkroom;
      case 'face': return Icons.face;
      case 'face_retouching': return Icons.face;
      case 'content_cut': return Icons.content_cut;
      case 'dry_cleaning': return Icons.dry_cleaning;
      case 'local_laundry_service': return Icons.local_laundry_service;
      case 'iron': return Icons.iron;
      case 'diamond': return Icons.diamond;
      case 'watch_later': return Icons.watch_later;
      case 'ring_volume': return Icons.ring_volume;
      case 'gesture': return Icons.gesture;

      // 工作职业（收入）
      case 'work': return Icons.work;
      case 'work_outline': return Icons.work_outline;
      case 'business': return Icons.business;
      case 'business_center': return Icons.business_center;
      case 'engineering': return Icons.engineering;
      case 'design_services': return Icons.design_services;
      case 'construction': return Icons.construction;
      case 'handyman': return Icons.handyman;
      case 'code': return Icons.code;
      case 'developer_mode': return Icons.developer_mode;
      case 'gavel': return Icons.gavel;
      case 'balance': return Icons.balance;
      case 'support_agent': return Icons.support_agent;

      // 金融理财（收入）
      case 'account_balance': return Icons.account_balance;
      case 'account_balance_wallet': return Icons.account_balance_wallet;
      case 'savings': return Icons.savings;
      case 'trending_up': return Icons.trending_up;
      case 'trending_down': return Icons.trending_down;
      case 'show_chart': return Icons.show_chart;
      case 'analytics': return Icons.analytics;
      case 'paid': return Icons.paid;
      case 'money': return Icons.attach_money;
      case 'currency_exchange': return Icons.currency_exchange;
      case 'credit_card': return Icons.credit_card;
      case 'payment': return Icons.payment;
      case 'receipt_long': return Icons.receipt_long;
      case 'request_quote': return Icons.request_quote;
      case 'monetization_on': return Icons.monetization_on;
      case 'price_change': return Icons.price_change;
      case 'euro': return Icons.euro_symbol;
      case 'yen': return Icons.currency_yen;

      // 奖励礼品（收入）
      case 'wallet': return Icons.wallet;
      case 'emoji_events': return Icons.emoji_events;
      case 'volunteer_activism': return Icons.volunteer_activism;
      case 'military_tech': return Icons.military_tech;
      case 'workspace_premium': return Icons.workspace_premium;
      case 'verified': return Icons.verified;
      case 'auto_awesome': return Icons.auto_awesome;
      case 'new_releases': return Icons.new_releases;
      case 'toll': return Icons.toll;
      case 'confirmation_number': return Icons.confirmation_number;

      // 投资收益（收入）
      case 'real_estate_agent': return Icons.home_work;
      case 'factory': return Icons.factory;
      case 'energy_savings_leaf': return Icons.eco;
      case 'solar_power': return Icons.solar_power;
      case 'oil_barrel': return Icons.propane_tank;
      case 'electric_bolt': return Icons.electric_bolt;

      // 其他收入
      case 'handshake': return Icons.handshake;
      case 'schedule': return Icons.schedule;
      case 'undo': return Icons.undo;
      case 'refresh': return Icons.refresh;
      case 'autorenew': return Icons.autorenew;
      case 'update': return Icons.update;
      case 'sync': return Icons.sync;
      case 'published_with_changes': return Icons.published_with_changes;
      case 'swap_horiz': return Icons.swap_horiz;
      case 'compare_arrows': return Icons.compare_arrows;
      case 'call_received': return Icons.call_received;
      case 'input': return Icons.input;
      case 'move_down': return Icons.move_down;
      case 'south': return Icons.south;
      case 'call_made': return Icons.call_made;

      // 其他杂项
      case 'camera_alt': return Icons.camera_alt;
      case 'photo_camera': return Icons.photo_camera;
      case 'videocam': return Icons.videocam;
      case 'print': return Icons.print;
      case 'mail': return Icons.mail;
      case 'local_post_office': return Icons.local_post_office;
      case 'public': return Icons.public;
      case 'place': return Icons.place;
      case 'location_on': return Icons.location_on;
      case 'map': return Icons.map;
      case 'explore': return Icons.explore;
      case 'compass': return Icons.explore;
      case 'access_time': return Icons.access_time;
      case 'security': return Icons.security;

      default:
        return Icons.category;
    }
  }

  /// 分类筛选和排序工具方法

  /// 对分类列表进行排序 (默认分类在前，自定义分类在后)
  static List<T> sortCategories<T>(
    List<T> categories,
    String Function(T) getNameFn,
    String Function(T) getKindFn,
  ) {
    final sorted = List<T>.from(categories);
    sorted.sort((a, b) {
      final aName = getNameFn(a);
      final aKind = getKindFn(a);
      final bName = getNameFn(b);
      final bKind = getKindFn(b);

      final aIsDefault = isDefaultCategory(aName, aKind);
      final bIsDefault = isDefaultCategory(bName, bKind);

      if (aIsDefault && bIsDefault) {
        // 两个都是默认分类，按预定义顺序排序
        return getDefaultCategoryWeight(aName, aKind)
            .compareTo(getDefaultCategoryWeight(bName, bKind));
      } else if (aIsDefault && !bIsDefault) {
        // a是默认分类，b不是，a排在前面
        return -1;
      } else if (!aIsDefault && bIsDefault) {
        // a不是默认分类，b是，b排在前面
        return 1;
      } else {
        // 两个都不是默认分类，按名称排序
        return aName.compareTo(bName);
      }
    });
    return sorted;
  }

  /// 筛选默认分类
  static List<T> filterDefaultCategories<T>(
    List<T> categories,
    String Function(T) getNameFn,
    String Function(T) getKindFn,
  ) {
    return categories.where((category) {
      return isDefaultCategory(getNameFn(category), getKindFn(category));
    }).toList();
  }

  /// 筛选自定义分类 (非默认分类)
  static List<T> filterCustomCategories<T>(
    List<T> categories,
    String Function(T) getNameFn,
    String Function(T) getKindFn,
  ) {
    return categories.where((category) {
      return !isDefaultCategory(getNameFn(category), getKindFn(category));
    }).toList();
  }

  /// 按分类类型筛选
  static List<T> filterCategoriesByKind<T>(
    List<T> categories,
    String kind,
    String Function(T) getKindFn,
  ) {
    return categories.where((category) {
      return getKindFn(category) == kind;
    }).toList();
  }

  /// 获取所有分类 (支出 + 收入，默认 + 自定义)
  static List<T> getAllCategories<T>(
    List<T> expenseCategories,
    List<T> incomeCategories,
  ) {
    return [...expenseCategories, ...incomeCategories];
  }

  /// 获取所有支出分类 (默认 + 自定义)
  static List<T> getAllExpenseCategories<T>(
    List<T> categories,
    String Function(T) getKindFn,
  ) {
    return filterCategoriesByKind(categories, 'expense', getKindFn);
  }

  /// 获取所有收入分类 (默认 + 自定义)
  static List<T> getAllIncomeCategories<T>(
    List<T> categories,
    String Function(T) getKindFn,
  ) {
    return filterCategoriesByKind(categories, 'income', getKindFn);
  }

  /// 获取分类数量统计
  static Map<String, int> getCategoryStats<T>(
    List<T> categories,
    String Function(T) getKindFn,
  ) {
    final expenses = getAllExpenseCategories(categories, getKindFn);
    final incomes = getAllIncomeCategories(categories, getKindFn);
    final defaultExpenses = filterDefaultCategories(expenses, (cat) => '', getKindFn);
    final defaultIncomes = filterDefaultCategories(incomes, (cat) => '', getKindFn);
    final customExpenses = filterCustomCategories(expenses, (cat) => '', getKindFn);
    final customIncomes = filterCustomCategories(incomes, (cat) => '', getKindFn);

    return {
      'total': categories.length,
      'expense': expenses.length,
      'income': incomes.length,
      'defaultExpense': defaultExpenses.length,
      'defaultIncome': defaultIncomes.length,
      'customExpense': customExpenses.length,
      'customIncome': customIncomes.length,
    };
  }

  /// 合并默认分类与数据库分类
  ///
  /// 确保所有默认分类都显示（即使数据库中不存在），并使用统一图标
  /// [dbCategories] 数据库中的分类列表
  /// [kind] 分类类型：'expense' 或 'income'
  /// 返回合并后的分类列表，按默认分类在前、自定义分类在后的顺序
  static List<T> mergeDefaultAndDbCategories<T>({
    required List<T> dbCategories,
    required String kind,
    required T Function({
      required int id,
      required String name,
      required String kind,
      required String icon,
    }) createCategory,
    required String Function(T) getNameFn,
    required String Function(T) getKindFn,
    required int Function(T) getIdFn,
  }) {
    // 从数据库分类中创建名称到分类的映射
    final Map<String, T> dbCategoryMap = {
      for (final cat in dbCategories) getNameFn(cat): cat
    };

    final List<T> result = [];

    // 首先添加所有默认分类（按默认顺序）
    final defaultCategories = kind == 'expense'
        ? defaultExpenseCategories
        : defaultIncomeCategories;

    for (final defaultName in defaultCategories) {
      final existingCategory = dbCategoryMap[defaultName];
      if (existingCategory != null) {
        // 数据库中存在，使用数据库的分类
        result.add(existingCategory);
        dbCategoryMap.remove(defaultName); // 从map中移除，避免重复
      } else {
        // 数据库中不存在，创建虚拟分类对象
        final virtualCategory = createCategory(
          id: -1, // 使用负数ID表示虚拟分类
          name: defaultName,
          kind: kind,
          icon: getDefaultCategoryIcon(defaultName, kind),
        );
        result.add(virtualCategory);
      }
    }

    // 然后添加剩余的自定义分类（按名称排序）
    final customCategories = dbCategoryMap.values.toList()
      ..sort((a, b) => getNameFn(a).compareTo(getNameFn(b)));
    result.addAll(customCategories);

    return result;
  }
}