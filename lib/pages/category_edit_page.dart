import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../data/repository.dart';
import '../widgets/ui/ui.dart';
import '../data/db.dart' as db;
import '../services/category_service.dart';
import '../l10n/app_localizations.dart';
import 'category_detail_page.dart';
import 'category_migration_page.dart';

class CategoryEditPage extends ConsumerStatefulWidget {
  final db.Category? category; // null表示新建
  final String kind; // expense 或 income
  
  const CategoryEditPage({
    super.key,
    this.category,
    required this.kind,
  });
  
  @override
  ConsumerState<CategoryEditPage> createState() => _CategoryEditPageState();
}

class _CategoryEditPageState extends ConsumerState<CategoryEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _selectedIcon;
  bool _saving = false;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    
    // 确保选中的图标在可用的图标组中存在
    final categoryIcon = widget.category?.icon;
    if (categoryIcon != null && categoryIcon.isNotEmpty && _isValidIcon(categoryIcon)) {
      _selectedIcon = categoryIcon;
    } else {
      _selectedIcon = 'category'; // 默认图标
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  bool get isEditing => widget.category != null;

  bool get isDefaultCategory => widget.category != null &&
      CategoryService.isDefaultCategory(widget.category!.name, widget.category!.kind);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: isEditing ? AppLocalizations.of(context).categoryEditTitle : AppLocalizations.of(context).categoryNewTitle,
            showBack: true,
            actions: isEditing && widget.category != null ? [
              // 分类详情按钮
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CategoryDetailPage(
                        categoryId: widget.category!.id,
                        categoryName: widget.category!.name,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics_outlined),
                tooltip: AppLocalizations.of(context).categoryDetailTooltip,
              ),
              // 分类迁移按钮
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CategoryMigrationPage(
                        preselectedFromCategory: widget.category!,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.move_down_outlined),
                tooltip: AppLocalizations.of(context).categoryMigrationTooltip,
              ),
            ] : null,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 分类类型提示
                  Card(
                    child: ListTile(
                      leading: Icon(
                        widget.kind == 'expense' ? Icons.trending_down : Icons.trending_up,
                        color: widget.kind == 'expense' ? Colors.red : Colors.green,
                      ),
                      title: Text(widget.kind == 'expense' ? AppLocalizations.of(context).categoryExpenseType : AppLocalizations.of(context).categoryIncomeType),
                    ),
                  ),

                  // 默认分类警告
                  if (isDefaultCategory) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.orange[50],
                      child: ListTile(
                        leading: Icon(
                          Icons.info_outline,
                          color: Colors.orange[700],
                        ),
                        title: Text(
                          AppLocalizations.of(context).categoryDefaultTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                        subtitle: Text(
                          AppLocalizations.of(context).categoryDefaultMessage,
                          style: TextStyle(color: Colors.orange[600]),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  
                  // 分类名称
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).categoryNameLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            enabled: !isDefaultCategory,
                            decoration: InputDecoration(
                              hintText: isDefaultCategory ? AppLocalizations.of(context).categoryNameHintDefault : AppLocalizations.of(context).categoryNameHint,
                              border: const OutlineInputBorder(),
                              fillColor: isDefaultCategory ? Colors.grey[100] : null,
                              filled: isDefaultCategory,
                            ),
                            maxLength: 4,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return AppLocalizations.of(context).categoryNameRequired;
                              }
                              if (value.trim().length > 4) {
                                return AppLocalizations.of(context).categoryNameTooLong;
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 图标选择
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).categoryIconLabel,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: isDefaultCategory ? Colors.grey[600] : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isDefaultCategory)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CategoryService.getCategoryIcon(_selectedIcon),
                                    size: 24,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    AppLocalizations.of(context).categoryIconDefaultMessage,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          else
                            _GroupedIconGrid(
                              selectedIcon: _selectedIcon,
                              kind: widget.kind,
                              onIconSelected: (icon) {
                                setState(() {
                                  _selectedIcon = icon;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (isEditing && !isDefaultCategory) ...[
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).categoryDangerousOperations,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: Text(AppLocalizations.of(context).categoryDeleteTitle),
                        subtitle: Text(AppLocalizations.of(context).categoryDeleteSubtitle),
                        onTap: isDefaultCategory ? null : _deleteCategory,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // 底部保存按钮
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: (_saving || isDefaultCategory) ? null : _saveCategory,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isDefaultCategory ? AppLocalizations.of(context).categoryDefaultCannotSave : AppLocalizations.of(context).commonSave),
            ),
          ),
        ],
      ),
    );
  }
  
  
  void _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _saving = true);
    
    try {
      final repo = ref.read(repositoryProvider);
      final name = _nameController.text.trim();
      
      if (isEditing) {
        // 编辑现有分类
        await repo.updateCategory(
          widget.category!.id,
          name: name,
          icon: _selectedIcon,
        );
        if (!mounted) return;
        showToast(context, AppLocalizations.of(context).categoryUpdated(name));
      } else {
        // 新建分类
        await repo.createCategory(
          name: name,
          kind: widget.kind,
          icon: _selectedIcon,
        );
        if (!mounted) return;
        showToast(context, AppLocalizations.of(context).categoryCreated(name));
      }
      
      // 刷新分类列表
      ref.invalidate(categoriesProvider);
      
      if (!mounted) return;
      Navigator.of(context).pop(true); // 返回true表示有更新
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).categorySaveError,
        message: '$e',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  
  void _deleteCategory() async {
    if (!isEditing) return;
    
    final repo = ref.read(repositoryProvider);
    
    // 检查是否有交易记录使用此分类
    final transactionCount = await repo.getTransactionCountByCategory(widget.category!.id);
    
    if (transactionCount > 0) {
      if (!mounted) return;
      await AppDialog.info(
        context,
        title: AppLocalizations.of(context).categoryCannotDelete,
        message: AppLocalizations.of(context).categoryCannotDeleteMessage(transactionCount),
      );
      return;
    }
    
    if (!mounted) return;
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: AppLocalizations.of(context).categoryDeleteConfirmTitle,
      message: AppLocalizations.of(context).categoryDeleteConfirmMessage(widget.category!.name),
      okLabel: AppLocalizations.of(context).commonDelete,
      cancelLabel: AppLocalizations.of(context).commonCancel,
    ) ?? false;
    
    if (!confirmed) return;
    
    try {
      await repo.deleteCategory(widget.category!.id);
      if (!mounted) return;
      
      // 刷新分类列表
      ref.invalidate(categoriesProvider);
      
      showToast(context, AppLocalizations.of(context).categoryDeleted(widget.category!.name));
      
      if (!mounted) return;
      Navigator.of(context).pop(true); // 返回true表示有更新
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).categoryDeleteError,
        message: '$e',
      );
    }
  }
  
  bool _isValidIcon(String iconName) {
    // 直接检查图标名称是否在 _getCategoryIcon 方法的映射中存在
    try {
      final iconData = _getCategoryIcon(iconName);
      // 如果返回的不是默认的 Icons.category，说明图标名称是有效的
      return iconData != Icons.category || iconName == 'category';
    } catch (e) {
      return false;
    }
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

class _GroupedIconGrid extends StatelessWidget {
  final String? selectedIcon;
  final String kind;
  final ValueChanged<String> onIconSelected;
  
  const _GroupedIconGrid({
    required this.selectedIcon,
    required this.kind,
    required this.onIconSelected,
  });
  
  @override
  Widget build(BuildContext context) {
    final iconGroups = _getIconGroups();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: iconGroups.map((group) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                group.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: group.icons.length,
              itemBuilder: (context, index) {
                final iconData = group.icons[index];
                final isSelected = selectedIcon == iconData.key;
                
                return InkWell(
                  onTap: () => onIconSelected(iconData.key),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                          : null,
                      border: Border.all(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      iconData.iconData,
                      size: 20,
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).iconTheme.color,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }
  
  List<_IconGroup> _getIconGroups() {
    if (kind == 'expense') {
      return [
        _IconGroup('基础', [
          _IconData('category', Icons.category),
          _IconData('label', Icons.label),
          _IconData('bookmark', Icons.bookmark),
          _IconData('star', Icons.star),
          _IconData('favorite', Icons.favorite),
          _IconData('circle', Icons.circle),
        ]),
        _IconGroup('餐饮美食', [
          _IconData('restaurant', Icons.restaurant),
          _IconData('local_dining', Icons.local_dining),
          _IconData('fastfood', Icons.fastfood),
          _IconData('local_cafe', Icons.local_cafe),
          _IconData('local_bar', Icons.local_bar),
          _IconData('local_pizza', Icons.local_pizza),
          _IconData('cake', Icons.cake),
          _IconData('coffee', Icons.coffee),
          _IconData('breakfast_dining', Icons.breakfast_dining),
          _IconData('lunch_dining', Icons.lunch_dining),
          _IconData('dinner_dining', Icons.dinner_dining),
          _IconData('icecream', Icons.icecream),
          _IconData('bakery_dining', Icons.bakery_dining),
          _IconData('liquor', Icons.liquor),
          _IconData('wine_bar', Icons.wine_bar),
          _IconData('restaurant_menu', Icons.restaurant_menu),
          _IconData('set_meal', Icons.set_meal),
          _IconData('ramen_dining', Icons.ramen_dining),
        ]),
        _IconGroup('交通出行', [
          _IconData('directions_car', Icons.directions_car),
          _IconData('directions_bus', Icons.directions_bus),
          _IconData('directions_subway', Icons.directions_subway),
          _IconData('local_taxi', Icons.local_taxi),
          _IconData('flight', Icons.flight),
          _IconData('train', Icons.train),
          _IconData('motorcycle', Icons.motorcycle),
          _IconData('directions_bike', Icons.directions_bike),
          _IconData('directions_walk', Icons.directions_walk),
          _IconData('boat', Icons.directions_boat),
          _IconData('electric_scooter', Icons.electric_scooter),
          _IconData('local_gas_station', Icons.local_gas_station),
          _IconData('local_parking', Icons.local_parking),
          _IconData('traffic', Icons.traffic),
          _IconData('directions_railway', Icons.directions_railway),
          _IconData('airport_shuttle', Icons.airport_shuttle),
          _IconData('pedal_bike', Icons.pedal_bike),
          _IconData('car_rental', Icons.car_rental),
        ]),
        _IconGroup('购物消费', [
          _IconData('shopping_cart', Icons.shopping_cart),
          _IconData('shopping_bag', Icons.shopping_bag),
          _IconData('store', Icons.store),
          _IconData('local_mall', Icons.local_mall),
          _IconData('local_grocery_store', Icons.local_grocery_store),
          _IconData('storefront', Icons.storefront),
          _IconData('shopping_basket', Icons.shopping_basket),
          _IconData('local_offer', Icons.local_offer),
          _IconData('receipt', Icons.receipt),
          _IconData('sell', Icons.sell),
          _IconData('price_check', Icons.price_check),
          _IconData('card_giftcard', Icons.card_giftcard),
          _IconData('redeem', Icons.redeem),
          _IconData('inventory', Icons.inventory),
          _IconData('add_shopping_cart', Icons.add_shopping_cart),
          _IconData('loyalty', Icons.loyalty),
        ]),
        _IconGroup('居住生活', [
          _IconData('home', Icons.home),
          _IconData('house', Icons.house),
          _IconData('apartment', Icons.apartment),
          _IconData('cleaning_services', Icons.cleaning_services),
          _IconData('plumbing', Icons.plumbing),
          _IconData('electrical_services', Icons.electrical_services),
          _IconData('flash_on', Icons.flash_on),
          _IconData('water_drop', Icons.water_drop),
          _IconData('air', Icons.air),
          _IconData('kitchen', Icons.kitchen),
          _IconData('bathtub', Icons.bathtub),
          _IconData('bed', Icons.bed),
          _IconData('chair', Icons.chair),
          _IconData('table_restaurant', Icons.table_restaurant),
          _IconData('lightbulb', Icons.lightbulb),
          _IconData('hvac', Icons.hvac),
          _IconData('roofing', Icons.roofing),
          _IconData('foundation', Icons.foundation),
        ]),
        _IconGroup('通讯设备', [
          _IconData('phone', Icons.phone),
          _IconData('smartphone', Icons.smartphone),
          _IconData('phone_android', Icons.phone_android),
          _IconData('phone_iphone', Icons.phone_iphone),
          _IconData('tablet', Icons.tablet),
          _IconData('laptop', Icons.laptop),
          _IconData('computer', Icons.computer),
          _IconData('desktop_windows', Icons.desktop_windows),
          _IconData('watch', Icons.watch),
          _IconData('headphones', Icons.headphones),
          _IconData('headset', Icons.headset),
          _IconData('keyboard', Icons.keyboard),
          _IconData('mouse', Icons.mouse),
          _IconData('wifi', Icons.wifi),
          _IconData('router', Icons.router),
          _IconData('cable', Icons.cable),
        ]),
        _IconGroup('娱乐休闲', [
          _IconData('movie', Icons.movie),
          _IconData('music_note', Icons.music_note),
          _IconData('sports_esports', Icons.sports_esports),
          _IconData('theater_comedy', Icons.theater_comedy),
          _IconData('casino', Icons.casino),
          _IconData('celebration', Icons.celebration),
          _IconData('party_mode', Icons.party_mode),
          _IconData('nightlife', Icons.nightlife),
          _IconData('local_activity', Icons.local_activity),
          _IconData('attractions', Icons.attractions),
          _IconData('beach_access', Icons.beach_access),
          _IconData('pool', Icons.pool),
          _IconData('spa', Icons.spa),
          _IconData('games', Icons.games),
          _IconData('sports', Icons.sports),
          _IconData('sports_soccer', Icons.sports_soccer),
          _IconData('sports_basketball', Icons.sports_basketball),
          _IconData('sports_tennis', Icons.sports_tennis),
        ]),
        _IconGroup('健康医疗', [
          _IconData('local_hospital', Icons.local_hospital),
          _IconData('medical_services', Icons.medical_services),
          _IconData('local_pharmacy', Icons.local_pharmacy),
          _IconData('health_and_safety', Icons.health_and_safety),
          _IconData('medication', Icons.medication),
          _IconData('fitness_center', Icons.fitness_center),
          _IconData('self_improvement', Icons.self_improvement),
          _IconData('psychology', Icons.psychology),
          _IconData('healing', Icons.healing),
          _IconData('monitor_heart', Icons.monitor_heart),
          _IconData('elderly', Icons.elderly),
          _IconData('accessible', Icons.accessible),
          _IconData('medical_information', Icons.medical_information),
          _IconData('biotech', Icons.biotech),
          _IconData('coronavirus', Icons.coronavirus),
          _IconData('vaccines', Icons.vaccines),
        ]),
        _IconGroup('教育学习', [
          _IconData('school', Icons.school),
          _IconData('book', Icons.book),
          _IconData('library_books', Icons.library_books),
          _IconData('menu_book', Icons.menu_book),
          _IconData('auto_stories', Icons.auto_stories),
          _IconData('edit', Icons.edit),
          _IconData('create', Icons.create),
          _IconData('calculate', Icons.calculate),
          _IconData('science', Icons.science),
          _IconData('brush', Icons.brush),
          _IconData('palette', Icons.palette),
          _IconData('music_video', Icons.music_video),
          _IconData('piano', Icons.piano),
          _IconData('translate', Icons.translate),
          _IconData('language', Icons.language),
          _IconData('quiz', Icons.quiz),
        ]),
        _IconGroup('宠物动物', [
          _IconData('pets', Icons.pets),
          _IconData('cruelty_free', Icons.cruelty_free),
          _IconData('bug_report', Icons.bug_report),
          _IconData('emoji_nature', Icons.emoji_nature),
          _IconData('park', Icons.park),
          _IconData('grass', Icons.grass),
          _IconData('forest', Icons.forest),
          _IconData('agriculture', Icons.agriculture),
          _IconData('eco', Icons.eco),
          _IconData('local_florist', Icons.local_florist),
          _IconData('yard', Icons.yard),
        ]),
        _IconGroup('服装美容', [
          _IconData('checkroom', Icons.checkroom),
          _IconData('face', Icons.face),
          _IconData('face_retouching', Icons.face),
          _IconData('content_cut', Icons.content_cut),
          _IconData('dry_cleaning', Icons.dry_cleaning),
          _IconData('local_laundry_service', Icons.local_laundry_service),
          _IconData('iron', Icons.iron),
          _IconData('diamond', Icons.diamond),
          _IconData('watch_later', Icons.watch_later),
          _IconData('ring_volume', Icons.ring_volume),
          _IconData('gesture', Icons.gesture),
        ]),
        _IconGroup('其他杂项', [
          _IconData('business', Icons.business),
          _IconData('work', Icons.work),
          _IconData('camera_alt', Icons.camera_alt),
          _IconData('photo_camera', Icons.photo_camera),
          _IconData('videocam', Icons.videocam),
          _IconData('print', Icons.print),
          _IconData('mail', Icons.mail),
          _IconData('local_post_office', Icons.local_post_office),
          _IconData('public', Icons.public),
          _IconData('place', Icons.place),
          _IconData('location_on', Icons.location_on),
          _IconData('map', Icons.map),
          _IconData('explore', Icons.explore),
          _IconData('compass', Icons.explore),
          _IconData('schedule', Icons.schedule),
          _IconData('access_time', Icons.access_time),
        ]),
      ];
    } else {
      return [
        _IconGroup('基础', [
          _IconData('category', Icons.category),
          _IconData('label', Icons.label),
          _IconData('bookmark', Icons.bookmark),
          _IconData('star', Icons.star),
          _IconData('favorite', Icons.favorite),
          _IconData('circle', Icons.circle),
        ]),
        _IconGroup('工作职业', [
          _IconData('work', Icons.work),
          _IconData('business', Icons.business),
          _IconData('business_center', Icons.business_center),
          _IconData('engineering', Icons.engineering),
          _IconData('design_services', Icons.design_services),
          _IconData('construction', Icons.construction),
          _IconData('code', Icons.code),
          _IconData('developer_mode', Icons.developer_mode),
          _IconData('computer', Icons.computer),
          _IconData('laptop', Icons.laptop),
          _IconData('biotech', Icons.biotech),
          _IconData('science', Icons.science),
          _IconData('psychology', Icons.psychology),
          _IconData('medical_services', Icons.medical_services),
          _IconData('school', Icons.school),
          _IconData('gavel', Icons.gavel),
          _IconData('balance', Icons.balance),
          _IconData('support_agent', Icons.support_agent),
        ]),
        _IconGroup('金融理财', [
          _IconData('account_balance', Icons.account_balance),
          _IconData('account_balance_wallet', Icons.account_balance_wallet),
          _IconData('savings', Icons.savings),
          _IconData('trending_up', Icons.trending_up),
          _IconData('trending_down', Icons.trending_down),
          _IconData('show_chart', Icons.show_chart),
          _IconData('analytics', Icons.analytics),
          _IconData('paid', Icons.paid),
          _IconData('money', Icons.attach_money),
          _IconData('currency_exchange', Icons.currency_exchange),
          _IconData('credit_card', Icons.credit_card),
          _IconData('payment', Icons.payment),
          _IconData('receipt_long', Icons.receipt_long),
          _IconData('request_quote', Icons.request_quote),
          _IconData('monetization_on', Icons.monetization_on),
          _IconData('price_change', Icons.price_change),
          _IconData('euro', Icons.euro_symbol),
          _IconData('yen', Icons.currency_yen),
        ]),
        _IconGroup('奖励礼品', [
          _IconData('card_giftcard', Icons.card_giftcard),
          _IconData('redeem', Icons.redeem),
          _IconData('wallet', Icons.wallet),
          _IconData('emoji_events', Icons.emoji_events),
          _IconData('celebration', Icons.celebration),
          _IconData('volunteer_activism', Icons.volunteer_activism),
          _IconData('loyalty', Icons.loyalty),
          _IconData('military_tech', Icons.military_tech),
          _IconData('workspace_premium', Icons.workspace_premium),
          _IconData('verified', Icons.verified),
          _IconData('diamond', Icons.diamond),
          _IconData('auto_awesome', Icons.auto_awesome),
          _IconData('new_releases', Icons.new_releases),
          _IconData('toll', Icons.toll),
          _IconData('casino', Icons.casino),
          _IconData('confirmation_number', Icons.confirmation_number),
        ]),
        _IconGroup('投资收益', [
          _IconData('apartment', Icons.apartment),
          _IconData('real_estate_agent', Icons.home_work),
          _IconData('home', Icons.home),
          _IconData('house', Icons.house),
          _IconData('store', Icons.store),
          _IconData('storefront', Icons.storefront),
          _IconData('factory', Icons.factory),
          _IconData('agriculture', Icons.agriculture),
          _IconData('energy_savings_leaf', Icons.eco),
          _IconData('solar_power', Icons.solar_power),
          _IconData('oil_barrel', Icons.propane_tank),
          _IconData('local_gas_station', Icons.local_gas_station),
          _IconData('electric_bolt', Icons.electric_bolt),
          _IconData('water_drop', Icons.water_drop),
        ]),
        _IconGroup('其他收入', [
          _IconData('handshake', Icons.handshake),
          _IconData('schedule', Icons.schedule),
          _IconData('undo', Icons.undo),
          _IconData('refresh', Icons.refresh),
          _IconData('autorenew', Icons.autorenew),
          _IconData('update', Icons.update),
          _IconData('sync', Icons.sync),
          _IconData('published_with_changes', Icons.published_with_changes),
          _IconData('swap_horiz', Icons.swap_horiz),
          _IconData('compare_arrows', Icons.compare_arrows),
          _IconData('call_received', Icons.call_received),
          _IconData('input', Icons.input),
          _IconData('move_down', Icons.move_down),
          _IconData('south', Icons.south),
          _IconData('call_made', Icons.call_made),
        ]),
      ];
    }
  }
}

class _IconGroup {
  final String title;
  final List<_IconData> icons;
  
  const _IconGroup(this.title, this.icons);
}

class _IconData {
  final String key;
  final IconData iconData;
  
  const _IconData(this.key, this.iconData);
}