import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../providers/database_providers.dart';
import '../data/repository.dart';
import '../widgets/ui/ui.dart';
import '../data/db.dart' as db;
import 'category_edit_page.dart';

class CategoryManagePage extends ConsumerStatefulWidget {
  const CategoryManagePage({super.key});
  
  @override
  ConsumerState<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage> with TickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final categoriesWithCountAsync = ref.watch(categoriesWithCountProvider);
    
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: '分类管理',
            showBack: true,
            actions: [
              IconButton(
                onPressed: () => _addCategory(),
                icon: const Icon(Icons.add),
                tooltip: '新建分类',
              ),
            ],
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '支出分类'),
              Tab(text: '收入分类'),
            ],
          ),
          Expanded(
            child: categoriesWithCountAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('加载失败: $error')),
              data: (categoriesWithCount) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _CategoryGridView(categoriesWithCount: categoriesWithCount, kind: 'expense'),
                    _CategoryGridView(categoriesWithCount: categoriesWithCount, kind: 'income'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  void _addCategory() async {
    final kind = _tabController.index == 0 ? 'expense' : 'income';
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryEditPage(kind: kind),
      ),
    );
    
    // 如果有更新，刷新分类列表
    if (result == true) {
      ref.invalidate(categoriesProvider);
      ref.invalidate(categoriesWithCountProvider);
    }
  }
}

class _CategoryGridView extends ConsumerWidget {
  final List<({db.Category category, int transactionCount})> categoriesWithCount;
  final String kind;
  
  const _CategoryGridView({
    required this.categoriesWithCount,
    required this.kind,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取默认分类名单
    final defaultNames = _getDefaultCategoryNames(kind);
    
    // 只显示自定义分类
    final customCategories = categoriesWithCount
        .where((item) => item.category.kind == kind && !defaultNames.contains(item.category.name))
        .toList();
    
    if (customCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无自定义分类',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角按钮添加',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: customCategories.length,
      itemBuilder: (context, index) {
        final categoryWithCount = customCategories[index];
        return _CategoryCard(
          category: categoryWithCount.category,
          transactionCount: categoryWithCount.transactionCount,
        );
      },
    );
  }
  
  Set<String> _getDefaultCategoryNames(String kind) {
    if (kind == 'expense') {
      return {
        '餐饮', '交通', '购物', '娱乐', '居家', '通讯', '水电', '住房', '医疗',
        '教育', '宠物', '运动', '数码', '旅行', '网购', '烟酒', '母婴', '美容',
        '维修', '社交', '学习', '汽车', '打车', '地铁', '外卖', '奶茶水果',
        '物业', '停车', '捐赠'
      };
    } else {
      return {
        '工资', '理财', '红包', '奖金', '报销', '兼职', '礼金', '利息', '退款'
      };
    }
  }
}

class _CategoryCard extends ConsumerWidget {
  final db.Category category;
  final int transactionCount;
  
  const _CategoryCard({
    required this.category,
    required this.transactionCount,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryEditPage(
              category: category,
              kind: category.kind,
            ),
          ),
        );
        
        // 如果有更新，刷新分类列表
        if (result == true) {
          ref.invalidate(categoriesProvider);
          ref.invalidate(categoriesWithCountProvider);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getCategoryIcon(category.icon),
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (transactionCount > 0) ...[
              const SizedBox(height: 2),
              Text(
                '$transactionCount笔',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  IconData _getCategoryIcon(String? iconName) {
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
      case 'business': return Icons.business;
      case 'business_center': return Icons.business_center;
      case 'engineering': return Icons.engineering;
      case 'design_services': return Icons.design_services;
      case 'construction': return Icons.construction;
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
      
      default:
        return Icons.category;
    }
  }
}