// Real production pages and local-only synthetic data, never a UI mock.
// Run only on a fresh, independently packaged QA installation. The English
// fixture is deliberately persisted in beecount.sqlite for a normal restart.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/main.dart' show MainApp, globalNavigatorKey;
import 'package:beecount/pages/account/accounts_page.dart';
import 'package:beecount/pages/budget/budget_page.dart';
import 'package:beecount/pages/budget/overview/bindings/budget_overview.dart';
import 'package:beecount/pages/category/category_manage_page.dart';
import 'package:beecount/pages/cloud/cloud_service_page.dart';
import 'package:beecount/pages/ai/ai_chat_page.dart';
import 'package:beecount/pages/data/import_confirm_page.dart';
import 'package:beecount/pages/data/import_page.dart';
import 'package:beecount/pages/main/analytics_page.dart';
import 'package:beecount/pages/main/analytics/widgets/analytics_content.dart';
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/pages/main/home/widgets/home_reminders.dart';
import 'package:beecount/services/ui/avatar_service.dart';
import 'package:beecount/pages/main/ledgers_page_new.dart';
import 'package:beecount/pages/main/mine_page.dart';
import 'package:beecount/pages/settings/personalize_page.dart';
import 'package:beecount/pages/tag/tag_manage_page.dart';
import 'package:beecount/pages/transaction/search_page.dart';
import 'package:beecount/pages/shared/transactions/transaction_list_item.dart';
import 'package:beecount/pages/transaction/recording/bindings/amount_editor_sheet.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/language_provider.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/providers/ui_state_providers.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show kReleaseMode, debugPrintSynchronously;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const qaRunId = String.fromEnvironment('QA_RUN_ID');
// Host records the whole native display and cuts these wall-clock clip spans.
const _captureMedia = bool.fromEnvironment('QA_CAPTURE_MEDIA');
const _mediaPackage = String.fromEnvironment('QA_ANDROID_MEDIA_APP_ID');
const qaAiKey = String.fromEnvironment('QA_AI_KEY');
const qaAiVision = bool.fromEnvironment('QA_AI_VISION', defaultValue: true);
const _nativeHostCapture = bool.fromEnvironment('QA_NATIVE_HOST_CAPTURE');
const _extras =
    bool.fromEnvironment('QA_SCREENSHOT_EXTRAS', defaultValue: true);

// Optional native logical viewport guard. Do not resize the Flutter surface:
// that can letterbox native screenshots rather than changing the actual device.
const _expectedWidth = int.fromEnvironment('QA_VIEWPORT_WIDTH');
const _expectedHeight = int.fromEnvironment('QA_VIEWPORT_HEIGHT');

// Retain the final real root and its database until the QA process exits.
ProviderContainer? _retainedContainer;
BeeDatabase? _retainedDatabase;

class _Copy {
  const _Copy(this.language);
  final String language;
  bool get english => language == 'en';
  String text(String zh, String en) => english ? en : zh;
  String get ledger => text('日常生活', 'Everyday life');
  String get travel => text('旅行计划', 'Travel plans');
  String get learning => text('自我成长', 'Learning');
  String get dinner => text('和朋友一起晚餐', 'Dinner with friends');
  String get profile => text('小满', 'Alex');
  Map<String, String> get categories => {
        'food': text('美食餐饮', 'Food & dining'),
        'groceries': text('日常采购', 'Groceries'),
        'transport': text('通勤出行', 'Transport'),
        'home': text('居家生活', 'Home & bills'),
        'shopping': text('品质购物', 'Shopping'),
        'fun': text('休闲娱乐', 'Leisure'),
        'health': text('健康运动', 'Health & fitness'),
        'study': text('学习提升', 'Education'),
        'salary': text('工作薪酬', 'Salary'),
        'freelance': text('业余收入', 'Freelance'),
        'interest': text('储蓄收益', 'Interest'),
        'medical': text('医疗健康', 'Health & medical'),
        'pets': text('宠物伙伴', 'Pets'),
        'beauty': text('美容护理', 'Beauty & care'),
        'gifts': text('人情往来', 'Gifts & family'),
      };
  Map<String, List<String>> get subCategories => {
        'food': [
          text('早餐', 'Breakfast'),
          text('晚餐', 'Dinner'),
          text('咖啡甜品', 'Café & dessert'),
        ],
        'transport': [
          text('地铁公交', 'Transit'),
          text('打车', 'Ride-hailing'),
        ],
        'shopping': [
          text('服饰鞋包', 'Apparel'),
          text('数码电子', 'Electronics'),
        ],
        'groceries': [
          text('生鲜果蔬', 'Fresh produce'),
          text('日用百货', 'Daily goods'),
        ],
        'home': [
          text('水电燃气', 'Utilities'),
          text('家居用品', 'Household items'),
        ],
      };
  Map<String, String> get accounts => {
        'bank': text('日常银行卡', 'Everyday bank'),
        'cash': text('随身钱包', 'Cash wallet'),
        'savings': text('安心储蓄', 'Savings'),
        'credit': text('生活信用卡', 'Credit card'),
      };
  Map<String, String> get tags => {
        'daily': text('日常', 'Everyday'),
        'friends': text('与朋友', 'With friends'),
        'work': text('工作', 'Work'),
        'weekend': text('周末', 'Weekend'),
        'essential': text('必需', 'Essentials'),
        'growth': text('成长', 'Growth'),
      };
}

class _Fixture {
  const _Fixture({
    required this.copy,
    required this.ledgerId,
    required this.featuredId,
    required this.categoryIds,
    required this.subCategoryIds,
    required this.accountIds,
    required this.tagIds,
    required this.monthIncome,
    required this.monthExpense,
    required this.transactionCount,
  });
  final _Copy copy;
  final int ledgerId, featuredId, transactionCount;
  final Map<String, int> categoryIds;
  final Map<String, int> subCategoryIds;
  final Map<String, int> accountIds, tagIds;
  final double monthIncome, monthExpense;

  Map<String, Object?> get manifest => {
        'locale': copy.language,
        'main_ledger_id': ledgerId,
        'main_ledger_name': copy.ledger,
        'featured_transaction_id': featuredId,
        'account_names': copy.accounts.values.toList(),
        'category_names': copy.categories.values.toList(),
        'sub_categories': copy.subCategories,
        'tag_names': copy.tags.values.toList(),
        'transaction_count': transactionCount,
        'current_month_income': monthIncome,
        'current_month_expense': monthExpense,
        'monthly_budget': 8500,
        'currency': 'CNY',
        'cloud': 'local_only',
      };
}

Future<_Fixture> _seed(BeeDatabase db, _Copy copy, DateTime now) async {
  final repo = LocalRepository(db);
  final ledgerId = await repo.createLedger(name: copy.ledger);
  final travelId = await repo.createLedger(name: copy.travel);
  final learningId = await repo.createLedger(name: copy.learning);
  final categories = <String, int>{};
  const icons = {
    'food': 'restaurant',
    'groceries': 'shopping_cart',
    'transport': 'directions_bus',
    'home': 'home',
    'shopping': 'shopping_bag',
    'fun': 'movie',
    'health': 'fitness_center',
    'study': 'school',
    'salary': 'work',
    'freelance': 'payments',
    'interest': 'trending_up',
    'medical': 'medical_services',
    'pets': 'pets',
    'beauty': 'spa',
    'gifts': 'card_giftcard',
  };
  for (final entry in copy.categories.entries) {
    categories[entry.key] = await repo.createCategory(
      name: entry.value,
      kind: const {'salary', 'freelance', 'interest'}.contains(entry.key)
          ? 'income'
          : 'expense',
      icon: icons[entry.key],
      sortOrder: categories.length,
    );
  }
  final subCategories = <String, int>{};
  for (final entry in copy.subCategories.entries) {
    for (var index = 0; index < entry.value.length; index++) {
      subCategories['${entry.key}:$index'] = await repo.createSubCategory(
        parentId: categories[entry.key]!,
        name: entry.value[index],
        kind: 'expense',
        sortOrder: index,
      );
    }
  }
  final accounts = <String, int>{};
  const opening = {
    'bank': 26000.0,
    'cash': 800.0,
    'savings': 32000.0,
    'credit': -680.0
  };
  for (final entry in copy.accounts.entries) {
    accounts[entry.key] = await repo.createAccount(
      ledgerId: ledgerId,
      name: entry.value,
      type: switch (entry.key) {
        'cash' => 'cash',
        'credit' => 'credit_card',
        _ => 'bank_card',
      },
      initialBalance: opening[entry.key]!,
      creditLimit: entry.key == 'credit' ? 20000 : null,
      billingDay: entry.key == 'credit' ? 10 : null,
      paymentDueDay: entry.key == 'credit' ? 28 : null,
    );
  }
  final tags = <String, int>{};
  const tagColors = [
    '#D49A27',
    '#8B71BD',
    '#4B8DA5',
    '#D28B70',
    '#6C9A78',
    '#6786BC'
  ];
  for (final entry in copy.tags.entries) {
    tags[entry.key] =
        await repo.createTag(name: entry.value, color: tagColors[tags.length]);
  }
  var count = 0;
  var income = 0.0, expense = 0.0, allIncome = 0.0, allExpense = 0.0;
  // Real calendar months, never a mocked clock or future-dated transaction.
  DateTime date(int offset, int position) {
    final month = DateTime(now.year, now.month - offset);
    final days =
        offset == 0 ? now.day : DateTime(month.year, month.month + 1, 0).day;
    final day = 1 + ((position - 1) * (days - 1) ~/ 30);
    return DateTime(month.year, month.month, day);
  }

  Future<int> add({
    required int offset,
    required int position,
    required double amount,
    required String category,
    String? subCategory,
    required String note,
    String account = 'bank',
    String type = 'expense',
    List<String> labels = const ['daily'],
    int? ledger,
    DateTime? at,
    String? to,
  }) async {
    final targetLedger = ledger ?? ledgerId;
    final id = await repo.addTransaction(
      ledgerId: targetLedger,
      type: type,
      amount: amount,
      categoryId: type == 'transfer'
          ? null
          : (subCategory == null
              ? categories[category]
              : subCategories[subCategory]),
      accountId: accounts[account],
      toAccountId: to == null ? null : accounts[to],
      happenedAt: at ?? date(offset, position),
      note: note,
      currencyCode: 'CNY',
      nativeAmount: amount,
    );
    await repo.updateTransactionTags(
      transactionId: id,
      tagIds: [for (final label in labels) tags[label]!],
    );
    count++;
    if (type == 'income') allIncome += amount;
    if (type == 'expense') allExpense += amount;
    if (offset == 0 && targetLedger == ledgerId) {
      if (type == 'income') income += amount;
      if (type == 'expense') expense += amount;
    }
    return id;
  }

  for (var offset = 3; offset >= 0; offset--) {
    await add(
        offset: offset,
        position: 1,
        amount: 12800,
        category: 'salary',
        note: copy.text('本月工资到账', 'Monthly salary'),
        type: 'income',
        labels: ['work']);
    await add(
        offset: offset,
        position: 12,
        amount: 1200,
        category: 'freelance',
        note: copy.text('设计项目收入', 'Design project'),
        type: 'income',
        labels: ['work', 'growth']);
    await add(
        offset: offset,
        position: 28,
        amount: 23.6,
        category: 'interest',
        account: 'savings',
        note: copy.text('储蓄利息', 'Savings interest'),
        type: 'income',
        labels: ['growth']);
    await add(
        offset: offset,
        position: 2,
        amount: 2800,
        category: 'home',
        note: copy.text('温暖小家的房租', 'Monthly rent'),
        labels: ['essential']);
    await add(
        offset: offset,
        position: 8,
        amount: 268,
        category: 'home',
        note: copy.text('水电与网络', 'Utilities & internet'),
        labels: ['essential']);
    await add(
        offset: offset,
        position: 6,
        amount: 26.5,
        category: 'food',
        subCategory: 'food:2',
        note: copy.text('楼下咖啡的拿铁', 'Latte at the corner café'),
        labels: ['daily']);
    await add(
        offset: offset,
        position: 14,
        amount: 9.5,
        category: 'transport',
        subCategory: 'transport:0',
        note: copy.text('地铁通勤', 'Metro commute'),
        labels: ['daily', 'work']);
    await add(
        offset: offset,
        position: 19,
        amount: 189,
        category: 'shopping',
        subCategory: 'shopping:0',
        note: copy.text('换季添件衣服', 'Seasonal clothes'),
        labels: ['weekend']);
    await add(
        offset: offset,
        position: 5,
        amount: 88.6,
        category: 'groceries',
        subCategory: 'groceries:0',
        note: copy.text('周末菜市场的生鲜', 'Farmers market produce'),
        labels: ['daily']);
    await add(
        offset: offset,
        position: 9,
        amount: 45.8,
        category: 'medical',
        note: copy.text('药房的常备药', 'Pharmacy essentials'),
        labels: ['essential']);
    await add(
        offset: offset,
        position: 16,
        amount: 129,
        category: 'pets',
        note: copy.text('猫粮和猫砂补货', 'Cat food and litter'),
        labels: ['essential']);
    await add(
        offset: offset,
        position: 18,
        amount: 76,
        category: 'home',
        subCategory: 'home:1',
        note: copy.text('家居小件补齐', 'Household odds and ends'),
        labels: ['daily']);
    await add(
        offset: offset,
        position: 20,
        amount: 56.2,
        category: 'groceries',
        subCategory: 'groceries:1',
        note: copy.text('纸巾洗衣液等日用品', 'Tissues, detergent and more'),
        labels: ['essential']);
    await add(
        offset: offset,
        position: 22,
        amount: 199,
        category: 'beauty',
        note: copy.text('护肤品补货', 'Skincare restock'),
        labels: ['weekend']);
    await add(
        offset: offset,
        position: 25,
        amount: 300,
        category: 'gifts',
        note: copy.text('给爸妈的心意', 'Gift for mom and dad'),
        labels: ['essential']);
    for (var i = 0; i < 8; i++) {
      await add(
          offset: offset,
          position: 3 + i * 4,
          amount: 38.5 + i * 3.2,
          category: 'food',
          account: 'cash',
          note: copy.text('工作日午餐', 'Lunch break'),
          labels: ['daily', 'work']);
      if (i.isEven) {
        await add(
            offset: offset,
            position: 4 + i * 3,
            amount: 98 + i * 12.5,
            category: 'groceries',
            note: copy.text('新鲜食材与水果', 'Fresh groceries'),
            labels: ['essential']);
      }
    }
    await add(
        offset: offset,
        position: 9,
        amount: 128,
        category: 'transport',
        note: copy.text('通勤交通卡', 'Transit pass'),
        labels: ['work']);
    await add(
        offset: offset,
        position: 15,
        amount: 45,
        category: 'transport',
        account: 'cash',
        note: copy.text('周末城市出行', 'Weekend ride'),
        labels: ['weekend']);
    await add(
        offset: offset,
        position: 18,
        amount: 659,
        category: 'shopping',
        account: 'credit',
        note: copy.text('舒适的新鞋', 'A new pair of shoes'),
        labels: ['weekend']);
    await add(
        offset: offset,
        position: 23,
        amount: 168,
        category: 'fun',
        note: copy.text('周末电影和咖啡', 'Movie & coffee'),
        labels: ['friends', 'weekend']);
    await add(
        offset: offset,
        position: 11,
        amount: 299,
        category: 'health',
        note: copy.text('每月运动计划', 'Monthly fitness plan'),
        labels: ['growth']);
    await add(
        offset: offset,
        position: 24,
        amount: 129,
        category: 'study',
        note: copy.text('阅读与课程', 'Books & courses'),
        labels: ['growth']);
    await add(
        offset: offset,
        position: 6,
        amount: 2500,
        category: 'interest',
        type: 'transfer',
        to: 'savings',
        note: copy.text('为未来存一笔', 'Move to savings'),
        labels: ['growth']);
    await add(
        offset: offset,
        position: 10,
        amount: 600,
        category: 'interest',
        type: 'transfer',
        to: 'cash',
        note: copy.text('钱包补充', 'Top up cash wallet'),
        labels: ['daily']);
  }
  // The latest actual transaction is the recognizable editor fixture.
  final featured = await add(
      offset: 0,
      position: 31,
      amount: 86.5,
      category: 'food',
      note: copy.dinner,
      labels: ['friends', 'weekend'],
      at: now);
  await add(
      offset: 1,
      position: 21,
      amount: 680,
      category: 'transport',
      ledger: travelId,
      note: copy.text('下一站的车票', 'Tickets for the next trip'),
      labels: ['weekend']);
  await add(
      offset: 0,
      position: 2,
      amount: 199,
      category: 'study',
      ledger: learningId,
      note: copy.text('新的学习课程', 'A new course'),
      labels: ['growth']);
  await repo.createBudget(ledgerId: ledgerId, type: 'total', amount: 8500);
  for (final budget in {
    'food': 1200.0,
    'groceries': 900.0,
    'shopping': 1000.0,
    'transport': 500.0
  }.entries) {
    await repo.createBudget(
        ledgerId: ledgerId,
        type: 'category',
        categoryId: categories[budget.key],
        amount: budget.value);
  }
  final actual = await repo.monthlyTotals(
      ledgerId: ledgerId, month: DateTime(now.year, now.month));
  expect(actual.$1, closeTo(income, .001));
  expect(actual.$2, closeTo(expense, .001));
  expect(expense, greaterThan(0));
  expect(expense, lessThan(8500));
  var balances = 0.0;
  for (final id in accounts.values) {
    balances += await repo.getAccountBalance(id);
  }
  expect(
      balances,
      closeTo(opening.values.reduce((a, b) => a + b) + allIncome - allExpense,
          .001),
      reason:
          'Income, expenses, transfers and opening balances must reconcile');
  expect(await repo.getAccountBalance(accounts['credit']!), lessThan(0));
  return _Fixture(
      copy: copy,
      ledgerId: ledgerId,
      featuredId: featured,
      categoryIds: categories,
      subCategoryIds: subCategories,
      accountIds: accounts,
      tagIds: tags,
      monthIncome: income,
      monthExpense: expense,
      transactionCount: count);
}

// Both locales use the user-supplied avatar, embedded for offline capture.
const _avatarZhBase64 =
    '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';
const _avatarEnBase64 = _avatarZhBase64;

Future<void> _prepareAvatar(String language) async {
  final bytes =
      base64Decode(language == 'en' ? _avatarEnBase64 : _avatarZhBase64);
  final path =
      await AvatarService.saveAvatarFromBytes(bytes, extension: '.jpg');
  expect(path, isNotNull);
}

class _CaptureBinding extends IntegrationTestWidgetsFlutterBinding {
  @override
  void handlePointerEventForSource(PointerEvent event,
      {TestBindingEventSource source = TestBindingEventSource.device}) {
    // Device-source dispatch still performs hit testing and gesture recognition,
    // without the live test binding's synthetic-pointer paint overlay.
    super.handlePointerEventForSource(event,
        source: _captureMedia ? TestBindingEventSource.device : source);
  }
}

class _StubImagePickerPlatform extends ImagePickerPlatform {
  XFile? next;
  @override
  Future<XFile?> getImageFromSource(
      {required ImageSource source,
      ImagePickerOptions options = const ImagePickerOptions()}) async {
    final file = next;
    if (file == null) throw StateError('No fixture image prepared');
    return file;
  }
}

/// A receipt the vision model can actually read: high-contrast text, an item
/// list and one unambiguous total.
Future<XFile> _renderReceipt(String language) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
  var y = 44.0;
  void line(String text, double size, FontWeight weight) {
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                fontSize: size,
                fontWeight: weight,
                color: const Color(0xFF151515))),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: 640);
    painter.paint(canvas, Offset(48, y));
    y += painter.height + 20;
  }

  line(language == 'en' ? 'BeeCount Cafe' : '蜜蜂咖啡', 46, FontWeight.w800);
  line(language == 'en' ? 'Receipt 2026-11-08 14:35' : '小票 2026-11-08 14:35',
      24, FontWeight.w400);
  line(language == 'en' ? 'Latte x1          18.00' : '拿铁 x1            18.00',
      32, FontWeight.w400);
  line(language == 'en' ? 'Croissant x1      10.00' : '可颂 x1            10.00',
      32, FontWeight.w400);
  line(language == 'en' ? 'TOTAL CNY 28.00' : '合计 ¥28.00', 42, FontWeight.w800);
  final image = await recorder.endRecording().toImage(720, (y + 56).round());
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/qa-ai-receipt-$language.png');
  await file.writeAsBytes(bytes);
  return XFile(file.path);
}

class _FakeFilePicker extends FilePicker {
  File? csv;
  @override
  Future<FilePickerResult?> pickFiles(
      {String? dialogTitle,
      String? initialDirectory,
      FileType type = FileType.any,
      List<String>? allowedExtensions,
      Function(FilePickerStatus)? onFileLoading,
      bool allowCompression = true,
      int compressionQuality = 30,
      bool allowMultiple = false,
      bool withData = false,
      bool withReadStream = false,
      bool lockParentWindow = false,
      bool readSequential = false}) async {
    final file = csv;
    if (file == null) return null;
    return FilePickerResult([
      PlatformFile(
          path: file.path,
          name: 'qa-bills.csv',
          size: file.lengthSync(),
          bytes: await file.readAsBytes())
    ]);
  }

  @override
  Future<bool> clearTemporaryFiles() async => true;

  @override
  Future<String?> getDirectoryPath(
          {String? dialogTitle,
          String? initialDirectory,
          bool lockParentWindow = false}) async =>
      null;

  @override
  Future<String?> saveFile(
          {String? dialogTitle,
          String? fileName,
          String? initialDirectory,
          FileType type = FileType.any,
          List<String>? allowedExtensions,
          Uint8List? bytes,
          bool lockParentWindow = false}) async =>
      null;
}

void main() {
  final binding = _CaptureBinding();
  binding.shouldPropagateDevicePointerEvents = true;
  final shots = <Map<String, Object?>>[];
  final fixtures = <Map<String, Object?>>[];
  final clips = <Map<String, Object?>>[];
  final mediaRuntime = Stopwatch();
  binding.reportData = {
    'run_id': qaRunId,
    'kind':
        _captureMedia ? 'production_app_media' : 'production_app_screenshots',
    'schema_version': 1,
    'complete': false,
    'native_host_capture': _nativeHostCapture,
    'captures': shots,
    'fixtures': fixtures,
    'media_clips': clips,
  };
  testWidgets('production App screenshots: zh/en x light/dark', (tester) async {
    mediaRuntime.start();
    // All guards run before changing preferences, creating data or mounting UI.
    expect(RegExp(r'^beecount-qa-[a-zA-Z0-9_-]+$').hasMatch(qaRunId), isTrue,
        reason: 'Pass a unique --dart-define=QA_RUN_ID=beecount-qa-...');
    final package = await PackageInfo.fromPlatform();
    expect(Platform.isIOS || Platform.isAndroid, isTrue);
    if (_captureMedia && kReleaseMode && Platform.isAndroid) {
      expect(
          RegExp(r'^com\.tntlikely\.beecount\.qa\.media[0-9]+\.dev$')
              .hasMatch(_mediaPackage),
          isTrue);
    }
    expect(
        package.packageName,
        Platform.isIOS
            ? 'com.tntlikely.beecount.qa'
            : (_captureMedia && kReleaseMode
                ? _mediaPackage
                : 'com.tntlikely.beecount.qa.dev.debug'),
        reason: 'Never run screenshots in the installed user application');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cloud_active_type') ?? 'local', 'local',
        reason: 'This target must not connect to any Cloud service');
    expect(
        (await CloudServiceStore().loadActive()).type, CloudBackendType.local);
    // Accounts/categories/tags are user-global, so separate ledgers alone are
    // NOT language isolation. Chinese uses its own real SQLite database; only
    // the final English fixture goes into the production default database.
    final englishDb = _captureMedia
        ? BeeDatabase.forTesting(NativeDatabase.memory())
        : BeeDatabase();
    _retainedDatabase = englishDb;
    for (final table in englishDb.allTables) {
      expect(await englishDb.select(table).get(), isEmpty,
          reason:
              'Use a fresh QA installation. Refusing to clear existing ${table.actualTableName} rows.');
    }
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId('group.com.tntlikely.beecount.qa');
    }
    final now = DateTime.now();
    binding.reportData!.addAll({
      'package_id': package.packageName,
      'app_version': package.version,
      'app_build': package.buildNumber,
      'fixture_anchor': now.toIso8601String(),
      'platform': Platform.operatingSystem,
      'build_mode': kReleaseMode ? 'release' : 'debug',
      'test_pointer_overlay': false,
      'screens_per_group': _captureMedia ? 0 : (_extras ? 12 : 6),
      'expected_media_clips': _captureMedia ? (qaAiVision ? 24 : 20) : 0,
    });
    await prefs.setBool('welcome_shown', true);
    await prefs.setBool('account_feature_enabled', true);
    await prefs.setBool('hideAmounts', false);
    await prefs.setBool('compactAmount', false);
    await prefs.setInt('fontScaleLevel', 0);
    await prefs.setString('noteDisplayMode', 'note');
    await prefs.setString('headerSkin', 'none');
    await prefs.setBool('skinAnimationEnabled', false);
    await prefs.setBool('analytics_header_hint_dismissed', true);
    await prefs.setBool('analytics_chart_hint_dismissed', true);
    await prefs.setBool('fab_speed_dial_tip_dismissed', true);
    await HomeReminderPolicy(now, prefs).dismissMonthly();
    if (_captureMedia) {
      expect(qaAiKey, isNotEmpty,
          reason:
              'AI media flows need QA_AI_KEY (see .tmp/ai-test.env, gitignored)');
      await prefs.setString(
          'ai_providers_v2',
          jsonEncode([
            {
              'id': 'zhipu_glm',
              'name': '智谱GLM',
              'isBuiltIn': true,
              'apiKey': qaAiKey,
              'baseUrl': 'https://open.bigmodel.cn/api/paas/v4',
              'textModel': 'glm-4-flash',
              'visionModel': 'glm-4v-flash',
              'audioModel': 'glm-4-voice',
              'createdAt': DateTime(2024, 1, 1).toIso8601String(),
            }
          ]));
      await prefs.setBool('ai_bill_extraction_enabled', true);
      binding.reportData!['ai_capture'] = true;
    }
    Size? viewport;
    var convertedSurface = false;
    ProviderContainer? container;

    void takeError(String description) {
      expect(tester.takeException(), isNull,
          reason: 'Production Flutter errors invalidate $description');
    }

    Future<void> waitFor(bool Function() ready, String description,
        {int tries = 200}) async {
      for (var i = 0; i < tries; i++) {
        if (_captureMedia && mediaRuntime.elapsedMilliseconds >= 600000) {
          fail('Media run exceeded its ten-minute interaction budget');
        }
        await tester.pump(const Duration(milliseconds: 100));
        takeError('waiting for $description');
        if (ready()) return;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      fail('Timed out waiting for $description');
    }

    Future<void> raster() async {
      // No pumpAndSettle: production can legitimately have ongoing animations.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      takeError('rastering a screenshot');
    }

    bool visible(Element element) {
      final render = element.findRenderObject();
      if (render is! RenderBox || !render.attached || !render.hasSize) {
        return false;
      }
      final rect = render.localToGlobal(Offset.zero) & render.size;
      return rect.width > 0 &&
          rect.height > 0 &&
          (Offset.zero & viewport!).contains(rect.center);
    }

    void visibleText(String text) {
      expect(
          find.textContaining(text, findRichText: true).evaluate().any(visible),
          isTrue,
          reason: 'Expected actual viewport text: "$text"');
    }

    Future<void> root(AppLocalizations l) async {
      globalNavigatorKey.currentState!.popUntil((route) => route.isFirst);
      await raster();
      if (container!.read(bottomTabIndexProvider) != 0) {
        await tester.tap(find.text(l.tabHome).last);
      }
      await waitFor(() => find.byType(HomePage).evaluate().isNotEmpty,
          'production HomePage');
      await raster();
    }

    Future<void> push(Widget page, Type type) async {
      unawaited(globalNavigatorKey.currentState!
          .push<void>(MaterialPageRoute<void>(builder: (_) => page)));
      await waitFor(() => find.byType(type).evaluate().isNotEmpty,
          'production $type route');
      await raster();
    }

    for (final language in ['zh', 'en']) {
      final db = language == 'en'
          ? englishDb
          : BeeDatabase.forTesting(NativeDatabase.memory());
      final fixture = await _seed(db, _Copy(language), now);
      fixtures.add(fixture.manifest);
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        // Remove the old Navigator/global key before disposing any listeners.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 300));
        container?.dispose();
        await prefs.setString('selected_language', language);
        await prefs.remove('selected_language_country');
        await prefs.setString('themeMode', mode.name);
        await prefs.setInt('current_ledger_id', fixture.ledgerId);
        await prefs.setInt(
            'default_expense_account_id', fixture.accountIds['bank']!);
        await prefs.setInt(
            'default_income_account_id', fixture.accountIds['bank']!);
        await prefs.setString('displayName', fixture.copy.profile);
        await _prepareAvatar(language);
        container = ProviderContainer(
            overrides: [databaseProvider.overrideWithValue(db)]);
        _retainedContainer = container;
        await container
            .read(languageProvider.notifier)
            .setLanguage(Locale(language));
        // Production preload and providers, not a replacement MaterialApp/host.
        await container.read(appSplashInitProvider.future);
        expect(container.read(repositoryProvider), isA<LocalRepository>());
        expect(container.read(themeModeProvider), mode);
        expect(container.read(currentLedgerIdProvider), fixture.ledgerId);
        expect(container.read(appInitStateProvider), AppInitState.ready);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container, child: const MainApp()));
        await waitFor(() => find.byType(HomePage).evaluate().isNotEmpty,
            '$language/${mode.name} MainApp home');
        if (Platform.isAndroid &&
            !_captureMedia &&
            !_nativeHostCapture &&
            !convertedSurface) {
          await binding.convertFlutterSurfaceToImage();
          convertedSurface = true;
        }
        await raster();
        final homeContext = tester.element(find.byType(HomePage));
        final currentViewport = MediaQuery.sizeOf(homeContext);
        viewport ??= currentViewport;
        expect(currentViewport, viewport,
            reason: 'Native viewport must stay fixed for the complete matrix');
        expect(currentViewport.width, greaterThanOrEqualTo(320));
        expect(currentViewport.height, greaterThanOrEqualTo(640));
        if (_expectedWidth > 0) {
          expect(currentViewport.width, closeTo(_expectedWidth, .1));
        }
        if (_expectedHeight > 0) {
          expect(currentViewport.height, closeTo(_expectedHeight, .1));
        }
        final l = AppLocalizations.of(homeContext);
        expect(l.localeName, language);
        binding.reportData!['viewport'] = {
          'logical_width': viewport.width,
          'logical_height': viewport.height,
          'device_pixel_ratio': tester.view.devicePixelRatio,
        };

        Future<void> capture(
            String scene, Type pageType, List<String> texts) async {
          await waitFor(
              () => find
                  .descendant(
                      of: find.byType(pageType),
                      matching: find.byWidgetPredicate((widget) =>
                          widget is CircularProgressIndicator &&
                          widget.value == null))
                  .evaluate()
                  .isEmpty,
              'production $pageType content, without a loading spinner');
          await raster();
          expect(find.byType(pageType), findsOneWidget,
              reason: 'Each scene must end on its real production page');
          final context = tester.element(find.byType(pageType));
          expect(Localizations.localeOf(context).languageCode, language);
          expect(Theme.of(context).brightness,
              mode == ThemeMode.dark ? Brightness.dark : Brightness.light);
          expect(MediaQuery.sizeOf(context), viewport);
          expect(MediaQuery.viewInsetsOf(context).bottom, 0,
              reason: 'The system keyboard must not cover a screenshot');
          for (final text in texts) {
            visibleText(text);
          }
          if (language == 'en') {
            for (final element in find
                .byWidgetPredicate(
                    (w) => w is Text || w is EditableText || w is RichText)
                .evaluate()) {
              if (!visible(element)) continue;
              final widget = element.widget;
              final text = switch (widget) {
                Text() => widget.data ?? widget.textSpan?.toPlainText() ?? '',
                EditableText() => widget.controller.text,
                RichText() => widget.text.toPlainText(),
                _ => '',
              };
              expect(RegExp(r'[㐀-鿿]').hasMatch(text), isFalse,
                  reason:
                      'English screenshots must not contain Chinese viewport text: $text');
            }
          }
          final name = '${language}_${mode.name}_$scene';
          if (_nativeHostCapture) {
            debugPrint('QA_SCREENSHOT_READY_$name');
            await Future<void>.delayed(const Duration(seconds: 3));
          } else {
            await binding.takeScreenshot(name);
          }
          shots.add({
            'name': name,
            'scene': scene,
            'locale': language,
            'theme': mode.name,
            'production_page': '$pageType',
            'viewport_assertions': texts,
            'status': 'PASS'
          });
        }

        if (_captureMedia) {
          final repo = container.read(repositoryProvider) as LocalRepository;
          final stubPicker = _StubImagePickerPlatform();
          ImagePickerPlatform.instance = stubPicker;
          Future<void> pace(int milliseconds) async {
            await tester.pump();
            await Future<void>.delayed(Duration(milliseconds: milliseconds));
            await tester.pump();
            takeError('recording native media');
          }

          Future<void> tap(Finder finder, {int hold = 400}) async {
            expect(finder, findsOneWidget);
            await tester.tap(finder);
            await pace(hold);
          }

          Future<void> mediaHome() async {
            globalNavigatorKey.currentState!.popUntil((route) => route.isFirst);
            // Drive the tab index through the provider: it is the same state
            // the bottom bar writes, without depending on bar label finders
            // mid-transition. Recorded flows always start from the home tab.
            container!.read(bottomTabIndexProvider.notifier).state = 0;
            await waitFor(() => find.byType(HomePage).evaluate().isNotEmpty,
                'media production Home');
            await pace(550);
            expect(find.byType(HomePage), findsOneWidget);
          }

          Finder rowFor(String note) => find.byWidgetPredicate(
              (widget) => widget is TransactionListItem && widget.title == note,
              skipOffstage: false);
          Future<void> editorReady() async {
            await waitFor(
                () =>
                    find.byType(AmountEditorSheet).evaluate().isNotEmpty &&
                    find
                        .byKey(const ValueKey('recording-save'))
                        .evaluate()
                        .isNotEmpty,
                'interactive production recording editor');
            await waitFor(
                () => find
                    .descendant(
                        of: find.byType(TransactionEditorPage),
                        matching: find.byWidgetPredicate((widget) =>
                            widget is CircularProgressIndicator &&
                            widget.value == null))
                    .evaluate()
                    .isEmpty,
                'loaded production recording references');
            await pace(600);
          }

          Future<void> amount(String value, {bool clear = false}) async {
            if (clear) {
              // Long press is the real keypad's clear action, not a state edit.
              await tester
                  .longPress(find.byKey(const ValueKey('recording-key-⌫')));
              await pace(180);
            }
            // Human rhythm: uneven key press holds, like a person typing.
            final rhythm = [420, 280, 360, 300];
            for (var i = 0; i < value.length; i++) {
              await tap(find.byKey(ValueKey('recording-key-${value[i]}')),
                  hold: rhythm[i % rhythm.length]);
            }
            expect(
                tester
                    .widget<Text>(
                        find.byKey(const ValueKey('recording-amount')))
                    .data,
                value);
          }

          Future<void> note(String value) async {
            final field = find.byKey(const ValueKey('recording-note'));
            if (field.hitTestable().evaluate().isEmpty &&
                find
                    .byKey(const ValueKey('recording-note-compact'))
                    .evaluate()
                    .isNotEmpty) {
              await tap(find.byKey(const ValueKey('recording-note-compact')));
            }
            await tap(field, hold: 450);
            // Release builds have no test text-input stub, so deliver each
            // keystroke through the same EditableTextState callback the real
            // IME channel invokes, at a human rhythm.
            final editable = tester.state<EditableTextState>(find
                .descendant(of: field, matching: find.byType(EditableText))
                .first);
            var typed = '';
            const rhythm = [170, 125, 210, 145, 190];
            var index = 0;
            for (final letter in value.runes) {
              typed += String.fromCharCode(letter);
              editable.updateEditingValue(TextEditingValue(
                  text: typed,
                  selection: TextSelection.collapsed(offset: typed.length)));
              await pace(rhythm[index % rhythm.length]);
              index++;
            }
            await pace(750);
            expect(tester.widget<TextField>(field).controller!.text, value);
            FocusManager.instance.primaryFocus?.unfocus();
            await pace(650);
          }

          Future<Transaction> save(Set<int> before, String expectedNote,
              double expectedAmount) async {
            final button = find.byKey(const ValueKey('recording-save'));
            expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
            await tap(button, hold: 550);
            await waitFor(
                () => find.byType(TransactionEditorPage).evaluate().isEmpty,
                'real recording save and route dismissal');
            final rows = await repo.getTransactionsByLedger(fixture.ledgerId);
            expect(rows.length, before.length + 1);
            final created = rows.singleWhere((row) => !before.contains(row.id));
            expect(created.note, expectedNote);
            expect(created.amount, closeTo(expectedAmount, .00001));
            expect(created.nativeAmount, closeTo(expectedAmount, .00001));
            expect(created.ledgerId, fixture.ledgerId);
            expect(created.currencyCode, 'CNY');
            expect(created.syncId, isNotNull);
            expect(created.syncId, isNotEmpty);
            expect(find.byType(HomePage), findsOneWidget);
            await waitFor(() => rowFor(expectedNote).evaluate().isNotEmpty,
                'saved transaction in the real production home feed');
            await tester.ensureVisible(rowFor(expectedNote).first);
            await pace(400);
            expect(rowFor(expectedNote).evaluate().any(visible), isTrue,
                reason:
                    'The saved production row must actually be in the native viewport');
            return created;
          }

          Future<void> clip(String scene,
              Future<Map<String, Object?>> Function() action) async {
            final entry = <String, Object?>{
              'name': '${language}_${mode.name}_$scene',
              'scene': scene,
              'locale': language,
              'theme': mode.name,
              'started_at_ms': DateTime.now().millisecondsSinceEpoch,
              'status': 'RUNNING',
              'assertions': <String>[],
            };
            clips.add(entry);
            await pace(700);
            entry.addAll(await action());
            final finalPage = entry['production_page'] == 'AnalyticsPage'
                ? find.byType(AnalyticsPage)
                : find.byType(HomePage);
            expect(finalPage, findsOneWidget);
            final finalContext = tester.element(finalPage);
            expect(Localizations.localeOf(finalContext).languageCode, language);
            expect(Theme.of(finalContext).brightness,
                mode == ThemeMode.dark ? Brightness.dark : Brightness.light);
            visibleText(entry['production_page'] == 'AnalyticsPage'
                ? l.tabInsights
                : l.tabHome);
            final elapsed = DateTime.now().millisecondsSinceEpoch -
                (entry['started_at_ms'] as int);
            if (elapsed < 8600) await pace(8600 - elapsed);
            final ended = DateTime.now().millisecondsSinceEpoch;
            expect(ended - (entry['started_at_ms'] as int), lessThan(45000),
                reason:
                    'Readable clips must leave time for all 12 native flows');
            expect((entry['assertions'] as List), isNotEmpty);
            expect(mediaRuntime.elapsedMilliseconds, lessThan(420000));
            entry['ended_at_ms'] = ended;
            entry['status'] = 'PASS';
          }

          await mediaHome();
          debugPrint('QA_MEDIA_GROUP_READY_${language}_${mode.name}');
          await Future<void>.delayed(const Duration(seconds: 3));
          await tester.pump();
          await clip('01-add-transaction', () async {
            final before =
                (await repo.getTransactionsByLedger(fixture.ledgerId))
                    .map((t) => t.id)
                    .toSet();
            await tap(find.text(l.tabRecord).last, hold: 350);
            await editorReady();
            expect(
                tester
                    .widget<TransactionEditorPage>(
                        find.byType(TransactionEditorPage))
                    .editingTransactionId,
                isNull);
            await tap(find.byKey(
                ValueKey('recording-category-${fixture.categoryIds['food']}')));
            expect(
                tester
                    .widget<AmountEditorSheet>(find.byType(AmountEditorSheet))
                    .categoryId,
                fixture.categoryIds['food']);
            await amount('37.5');
            final addedNote = fixture.copy.text('午后的一杯咖啡', 'Afternoon coffee');
            await note(addedNote);
            final created = await save(before, addedNote, 37.5);
            expect(created.categoryId, fixture.categoryIds['food']);
            expect(created.accountId, fixture.accountIds['bank']);
            return {
              'production_page': 'HomePage',
              'assertions': [
                'Home add entry opened the production editor',
                'Real category, numeric keypad and note field were used',
                'Save created exactly one persisted transaction with expected category, account and amount',
                'The actual saved row is present on production HomePage'
              ],
              'transaction': created.toJson(),
            };
          });

          await mediaHome();
          if (qaAiVision) await mediaHome();
          if (qaAiVision)
            await clip('03-ai-photo-recognition', () async {
              final baselineIds =
                  (await repo.getTransactionsByLedger(fixture.ledgerId))
                      .map((row) => row.id)
                      .toSet();
              stubPicker.next = await _renderReceipt(language);
              final pending = await SharedPreferences.getInstance();
              // The vision model may split the receipt into its item rows or
              // return one total; accept either as long as the new expense sums
              // to the receipt total. Retry once on a no-bill answer.
              Transaction? created;
              for (var attempt = 0; attempt < 3 && created == null; attempt++) {
                await pending.setString(
                    'pending_deeplink_action',
                    jsonEncode({
                      'action': 'image',
                      'ts': DateTime.now().millisecondsSinceEpoch
                    }));
                if (attempt > 0) {
                  // Free-tier vision rate limits (HTTP 429) need a cooldown;
                  // the gap is cut out of every GIF by the wall-clock spans.
                  await pace(20000);
                }
                binding
                    .handleAppLifecycleStateChanged(AppLifecycleState.hidden);
                binding
                    .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
                // The loading dialog can flash by on a fast failure (free-tier
                // quota errors close it in ~300ms), so poll for any settled
                // outcome: booked rows, a failure/no-bill toast, or a timeout.
                var settled = false;
                for (var i = 0; i < 600 && !settled; i++) {
                  await pace(150);
                  final rows =
                      await repo.getTransactionsByLedger(fixture.ledgerId);
                  final newRows = rows
                      .where((row) => !baselineIds.contains(row.id))
                      .toList();
                  final expenseSum = newRows
                      .where((row) => row.type == 'expense')
                      .fold(0.0, (sum, row) => sum + row.amount);
                  if (newRows.isNotEmpty && (expenseSum - 28.0).abs() < .01) {
                    created = newRows.first;
                    settled = true;
                    break;
                  }
                  final failedToast = find
                      .textContaining(l.aiOcrFailed(''))
                      .evaluate()
                      .isNotEmpty;
                  final noBill =
                      find.textContaining(l.aiOcrNoBill).evaluate().isNotEmpty;
                  if (failedToast || noBill) settled = true;
                }
              }
              expect(created, isNotNull,
                  reason:
                      'The vision model must book the receipt (total 28.00), possibly split into item rows');
              expect(created!.type, 'expense');
              expect((created.note ?? '').isNotEmpty, isTrue,
                  reason: 'The AI-created note must be readable on the row');
              await mediaHome();
              final aiRow = created!;
              expect(aiRow.note?.isNotEmpty ?? false, isTrue,
                  reason: 'The AI-created note must be readable on the row');
              await waitFor(() => rowFor(aiRow.note!).evaluate().isNotEmpty,
                  'AI-created row visible on production home',
                  tries: 100);
              return {
                'production_page': 'HomePage',
                'assertions': [
                  'Deep link opened the real gallery-billing flow with a fixture receipt',
                  'The live vision model read the receipt and booked the expense',
                  'New rows sum to the receipt total (28.00)',
                  'The AI-created row is visible on the production home feed'
                ],
                'transaction': aiRow.toJson()
              };
            });
          await mediaHome();
          await clip('04-data-analysis', () async {
            await tap(find.text(l.tabInsights).last, hold: 350);
            await waitFor(
                () => find.byType(AnalyticsContent).evaluate().isNotEmpty,
                'production analytics from real bottom navigation');
            expect(find.byType(AnalyticsPage), findsOneWidget);
            await tap(find.text(l.analyticsYear));
            await waitFor(
                () =>
                    find.byType(AnalyticsContent).evaluate().isNotEmpty &&
                    tester
                            .widget<AnalyticsContent>(
                                find.byType(AnalyticsContent))
                            .scope ==
                        'year',
                'analytics year period');
            await tap(find
                .descendant(
                    of: find.byType(AnalyticsContent),
                    matching: find.text(l.homeIncome))
                .first);
            final annual = await repo.yearlyTotals(
                ledgerId: fixture.ledgerId, year: now.year);
            await waitFor(
                () =>
                    find.byType(AnalyticsContent).evaluate().isNotEmpty &&
                    tester
                            .widget<AnalyticsContent>(
                                find.byType(AnalyticsContent))
                            .type ==
                        'income',
                'analytics income view');
            final incomeView =
                tester.widget<AnalyticsContent>(find.byType(AnalyticsContent));
            expect(incomeView.scope, 'year');
            expect(incomeView.data.total, closeTo(annual.$1, .001));
            expect(incomeView.data.count, greaterThan(0));
            await pace(650);
            await tap(find.text(l.analyticsMonth));
            await waitFor(
                () =>
                    find.byType(AnalyticsContent).evaluate().isNotEmpty &&
                    tester
                            .widget<AnalyticsContent>(
                                find.byType(AnalyticsContent))
                            .scope ==
                        'month',
                'analytics return to current month');
            await tap(find
                .descendant(
                    of: find.byType(AnalyticsContent),
                    matching: find.text(l.homeExpense))
                .first);
            final monthly = await repo.monthlyTotals(
                ledgerId: fixture.ledgerId,
                month: DateTime(now.year, now.month));
            final expenseView =
                tester.widget<AnalyticsContent>(find.byType(AnalyticsContent));
            expect(expenseView.scope, 'month');
            expect(expenseView.type, 'expense');
            expect(expenseView.data.total, closeTo(monthly.$2, .001));
            expect(find.byType(AnalyticsPage), findsOneWidget);
            return {
              'production_page': 'AnalyticsPage',
              'assertions': [
                'Home bottom navigation opened production AnalyticsPage',
                'Year/income and month/expense controls changed the real rendered views',
                'Both displayed totals equal actual repository queries',
                'Populated production AnalyticsPage remains visible'
              ],
              'annual_income': annual.$1,
              'monthly_expense': monthly.$2
            };
          });

          await mediaHome();
          await clip('05-copy-transaction', () async {
            final original =
                (await repo.getTransactionById(fixture.featuredId))!;
            final originalTags = (await repo.getTagsForTransaction(original.id))
                .map((t) => t.id)
                .toList();
            final before =
                (await repo.getTransactionsByLedger(fixture.ledgerId))
                    .map((t) => t.id)
                    .toSet();
            await waitFor(
                () => rowFor(fixture.copy.dinner).evaluate().isNotEmpty,
                'original home transaction for a real long press');
            final row = rowFor(fixture.copy.dinner).first;
            await tester.ensureVisible(row);
            await pace(250);
            // flutter_list_view 1.x does not expose onstage children correctly.
            // Traverse actual row elements and deliver a real pointer sequence.
            final position = tester.getTopLeft(row) + const Offset(100, 16);
            final gesture = await tester.startGesture(position);
            await pace(750);
            await gesture.up();
            await waitFor(
                () => find.text(l.transactionCopyAction).evaluate().isNotEmpty,
                'real home long-press copy menu');
            // The popup route animates in; tap only after it settles so the
            // menu item is actually hit-tested where the text renders.
            await pace(500);
            await tap(find.text(l.transactionCopyAction), hold: 350);
            await editorReady();
            final page = tester.widget<TransactionEditorPage>(
                find.byType(TransactionEditorPage));
            final prefill = tester
                .widget<AmountEditorSheet>(find.byType(AmountEditorSheet));
            expect(page.isCopy, isTrue);
            expect(prefill.editingTransactionId, isNull);
            expect(prefill.initialAmount, original.amount);
            expect(prefill.initialNote, original.note);
            expect(prefill.initialAccountId, original.accountId);
            expect(prefill.initialTagIds, unorderedEquals(originalTags));
            await amount('42.8', clear: true);
            final copiedNote =
                fixture.copy.text('再约一次朋友晚餐', 'Another dinner together');
            await note(copiedNote);
            final created = await save(before, copiedNote, 42.8);
            expect(created.id, isNot(original.id));
            expect(created.syncId, isNot(original.syncId));
            expect(created.categoryId, original.categoryId);
            expect(created.accountId, original.accountId);
            expect(
                (await repo.getTagsForTransaction(created.id)).map((t) => t.id),
                unorderedEquals(originalTags));
            final unchanged = (await repo.getTransactionById(original.id))!;
            expect(unchanged.toJson(), original.toJson());
            expect(find.byType(HomePage), findsOneWidget);
            return {
              'production_page': 'HomePage',
              'assertions': [
                'Real home long press and production copy menu opened a new prefilled editor',
                'Real clear/keypad and note controls changed the copied amount and note',
                'Exactly one copy has independent local and sync identities with inherited category/account/tags',
                'Original database row is byte-for-field unchanged; real copied home row is visible'
              ],
              'source_before': original.toJson(),
              'source_after': unchanged.toJson(),
              'copy': created.toJson()
            };
          });
          await mediaHome();
          await mediaHome();
          await clip('02-ai-chat', () async {
            await tap(find.text('AI').first, hold: 450);
            await waitFor(() => find.byType(AIChatPage).evaluate().isNotEmpty,
                'production AI chat page');
            final field = find
                .descendant(
                    of: find.byType(AIChatPage),
                    matching: find.byType(TextField))
                .first;
            await tap(field, hold: 450);
            final editable = tester.state<EditableTextState>(find
                .descendant(of: field, matching: find.byType(EditableText))
                .first);
            final question = fixture.copy
                .text('这个月我花了多少钱？', 'How much did I spend this month?');
            var typed = '';
            const rhythm = [150, 190, 130, 170];
            var index = 0;
            for (final letter in question.runes) {
              typed += String.fromCharCode(letter);
              editable.updateEditingValue(TextEditingValue(
                  text: typed,
                  selection: TextSelection.collapsed(offset: typed.length)));
              await pace(rhythm[index % rhythm.length]);
              index++;
            }
            await pace(400);
            await tap(find.byKey(const ValueKey('ai-chat-send')), hold: 400);
            // The agent runs real ledger tools against the live model; wait
            // for the streamed answer and the composer to leave busy state.
            await waitFor(
                () =>
                    find
                        .byWidgetPredicate((widget) =>
                            widget.key is ValueKey &&
                            '${(widget.key as ValueKey).value}'
                                .startsWith('agent-answer-'))
                        .evaluate()
                        .isNotEmpty &&
                    find.byIcon(Icons.send).evaluate().isNotEmpty,
                'real AI assistant answer',
                tries: 600);
            expect(find.textContaining(l.aiChatConfigWarning), findsNothing);
            await pace(900);
            await mediaHome();
            expect(find.byType(HomePage), findsOneWidget);
            return {
              'production_page': 'AIChatPage',
              'assertions': [
                'Home header opened the production AI assistant',
                'The question was typed and sent through the real composer',
                'A real model answer rendered after live ledger tool runs',
                'No unconfigured-AI warning appeared'
              ]
            };
          });

          await mediaHome();
          await clip('06-import-ledger', () async {
            final before =
                (await repo.getTransactionsByLedger(fixture.ledgerId)).length;
            final docs = await getTemporaryDirectory();
            final csv = File('${docs.path}/qa-bills.csv');
            String stamp(DateTime d) =>
                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            final day = DateTime.now().subtract(const Duration(days: 1));
            final day2 = DateTime.now().subtract(const Duration(days: 2));
            await csv.writeAsString([
              // The category column is required: without it the confirm
              // page blocks on "select a category first" instead of
              // starting the import.
              '日期,类型,金额,分类,备注',
              '${stamp(day)},支出,28.0,美食餐饮,楼下咖啡拿铁',
              '${stamp(day)},收入,120.0,工作薪酬,闲置出售',
              '${stamp(day2)},支出,15.5,通勤出行,地铁通勤',
              ''
            ].join('\n'));
            final fakePicker = _FakeFilePicker()..csv = csv;
            FilePicker.platform = fakePicker;
            await tap(find.text(l.tabMine).last, hold: 400);
            await waitFor(() => find.byType(MinePage).evaluate().isNotEmpty,
                'Mine tab for import');
            await tap(find.text(l.dataManagement), hold: 450);
            // The data management page is a lazy ListView; scroll the import
            // tile into the built viewport before tapping it.
            final importTile = find.text(l.mineImport);
            for (var i = 0; i < 8 && importTile.evaluate().isEmpty; i++) {
              await tester.drag(
                  find.byType(Scrollable).first, const Offset(0, -320));
              await pace(250);
            }
            await waitFor(() => importTile.evaluate().isNotEmpty,
                'data management import tile');
            await pace(300);
            await tap(find.text(l.mineImport), hold: 450);
            await waitFor(() => find.byType(ImportPage).evaluate().isNotEmpty,
                'production import page');
            await tap(find.text(l.importChooseFile), hold: 450);
            await waitFor(
                () => find.byType(ImportConfirmPage).evaluate().isNotEmpty,
                'real CSV parsed into the mapping step',
                tries: 200);
            await pace(600);
            await tap(find.text(l.importNextStep), hold: 450);
            await pace(400);
            await tap(find.text(l.importStartImport), hold: 500);
            // A currency-confirmation dialog pops up for imported accounts;
            // confirm it too (its button reuses the same label).
            await pace(1200);
            if (find
                .text(l.importAccountCurrencyPreview)
                .evaluate()
                .isNotEmpty) {
              await tap(find.text(l.importStartImport).last, hold: 500);
            }
            var imported = false;
            for (var i = 0; i < 300 && !imported; i++) {
              await pace(100);
              imported = (await repo.getTransactionsByLedger(fixture.ledgerId))
                      .length ==
                  before + 3;
            }
            expect(imported, isTrue,
                reason: 'Three CSV rows must land through the import UI');
            await mediaHome();
            return {
              'production_page': 'HomePage',
              'assertions': [
                'The real file-picker flow selected a fixture CSV',
                'The production parser mapped and confirmed the columns',
                'Three CSV rows landed in the ledger through the import UI'
              ],
              'imported_rows': 3
            };
          });

          await mediaHome();
          debugPrint('QA_MEDIA_GROUP_DONE_${language}_${mode.name}');
          await Future<void>.delayed(const Duration(seconds: 1));
          await tester.pump();
          continue;
        }

        await capture('01-home', HomePage,
            [fixture.copy.ledger, l.v4HomeMonthIncome, l.v4HomeMonthExpense]);
        await tester.tap(find.text(l.tabInsights).last);
        await waitFor(() => find.byType(AnalyticsContent).evaluate().isNotEmpty,
            'loaded analytics data');
        await capture('02-analytics', AnalyticsPage,
            [l.tabInsights, fixture.copy.ledger]);
        await tester.tap(find.text(l.tabAssets).last);
        await waitFor(
            () => find.text(l.v4AssetsAllAccounts).evaluate().isNotEmpty,
            'loaded real accounts');
        await capture(
            '03-accounts', AccountsPage, [l.tabAssets, l.v4AssetsAllAccounts]);
        await root(l);
        await push(const LedgersPageNew(), LedgersPageNew);
        await waitFor(
            () => find.text(fixture.copy.ledger).evaluate().any(visible),
            'populated ledger cards');
        await capture('04-ledgers', LedgersPageNew,
            [l.ledgersTitle, fixture.copy.ledger]);
        await root(l);
        final source =
            (await LocalRepository(db).getTransactionById(fixture.featuredId))!;
        await push(
            TransactionEditorPage(
              initialKind: source.type,
              editingTransactionId: source.id,
              initialCategoryId: source.categoryId,
              initialAccountId: source.accountId,
              initialAmount: source.amount,
              initialNote: source.note,
              initialDate: source.happenedAt,
              initialTagIds: [
                fixture.tagIds['friends']!,
                fixture.tagIds['weekend']!
              ],
              initialCurrencyCode: source.currencyCode,
              initialNativeAmount: source.nativeAmount,
            ),
            TransactionEditorPage);
        await waitFor(
            () => find.byType(AmountEditorSheet).evaluate().isNotEmpty,
            'real initialized amount editor');
        final editor =
            tester.widget<AmountEditorSheet>(find.byType(AmountEditorSheet));
        expect(editor.editingTransactionId, fixture.featuredId);
        expect(editor.initialAmount, 86.5);
        // Expand the food parent so the capture shows second-level options.
        await tester.tap(find.byKey(
            ValueKey('recording-category-${fixture.categoryIds['food']}')));
        await tester.pump(const Duration(milliseconds: 350));
        await waitFor(
            () => find
                .byKey(ValueKey(
                    'recording-category-${fixture.subCategoryIds['food:2']}'))
                .evaluate()
                .isNotEmpty,
            'expanded second-level category choices');
        FocusManager.instance.primaryFocus?.unfocus();
        await capture('05-transaction', TransactionEditorPage, [
          l.categoryExpense,
          fixture.copy.dinner,
          fixture.copy.subCategories['food']![2],
        ]);
        await root(l);
        await push(const BudgetPage(), BudgetPage);
        await waitFor(
            () => find.byType(BudgetOverviewContent).evaluate().isNotEmpty,
            'real budget usage');
        await capture(
            '06-budgets', BudgetPage, [l.budgetTitle, l.budgetMonthlyBudget]);
        await root(l);
        if (_extras) {
          await tester.tap(find.text(l.tabMine).last);
          await waitFor(() => find.byType(MinePage).evaluate().isNotEmpty,
              'production Mine tab');
          await capture(
              '07-mine', MinePage, [l.mineTitle, fixture.copy.profile]);
          await root(l);
          await push(const TagManagePage(), TagManagePage);
          await waitFor(
              () => find
                  .text(fixture.copy.tags['daily']!)
                  .evaluate()
                  .any(visible),
              'populated production tag library');
          await capture('08-tags', TagManagePage,
              [l.tagManageTitle, fixture.copy.tags['daily']!]);
          await root(l);
          await push(const CloudServicePage(), CloudServicePage);
          await tester.tap(find.text(l.cloudTabCloudSync));
          await waitFor(
              () =>
                  find.text(l.cloudBeeCountCloudTitle).evaluate().any(visible),
              'real, unconfigured BeeCount Cloud card');
          expect((await CloudServiceStore().loadActive()).type,
              CloudBackendType.local);
          await capture('09-cloud', CloudServicePage,
              [l.mineCloudService, l.cloudBeeCountCloudTitle]);
          await root(l);
          await push(const CategoryManagePage(), CategoryManagePage);
          await waitFor(
              () => find
                  .text(fixture.copy.categories['food']!)
                  .evaluate()
                  .any(visible),
              'populated production category manager');
          await tester.tap(find.text(fixture.copy.categories['food']!).first);
          await waitFor(
              () => find
                  .text(fixture.copy.subCategories['food']![0])
                  .evaluate()
                  .any(visible),
              'expanded second-level categories');
          await capture('10-categories', CategoryManagePage, [
            l.categoryTitle,
            fixture.copy.categories['food']!,
            fixture.copy.subCategories['food']![0],
          ]);
          await root(l);
          await push(const PersonalizePage(), PersonalizePage);
          await capture(
              '11-personalization', PersonalizePage, [l.personalizeTitle]);
          await root(l);
          await push(const SearchPage(), SearchPage);
          await tester.enterText(
              find
                  .descendant(
                      of: find.byType(SearchPage),
                      matching: find.byType(TextField))
                  .first,
              fixture.copy.text('午餐', 'Lunch'));
          FocusManager.instance.primaryFocus?.unfocus();
          await waitFor(
              () => find.text(l.searchResultsCount(32)).evaluate().any(visible),
              '32 actual localized lunch search results');
          await capture('12-search', SearchPage,
              [l.v4SearchTitle, l.searchResultsCount(32)]);
          await root(l);
        }
        expect(
            (await LocalRepository(db)
                    .getTransactionsByLedger(fixture.ledgerId))
                .length,
            fixture.transactionCount - 2,
            reason:
                'Opening/canceling the editor must not change fixture transactions');
      }
      if (language == 'zh') {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 300));
        container!.dispose();
        container = null;
        _retainedContainer = null;
        await db.close();
      }
    }
    expect(shots.length, _captureMedia ? 0 : (_extras ? 48 : 24));
    expect(clips.length, _captureMedia ? (qaAiVision ? 24 : 20) : 0);
    if (_captureMedia) {
      expect(mediaRuntime.elapsedMilliseconds, lessThan(600000),
          reason:
              'Each group is recorded separately; all flows must finish within seven minutes');
    }
    expect(prefs.getString('selected_language'), 'en');
    expect(prefs.getString('themeMode'), 'dark');
    expect(_retainedContainer!.read(databaseProvider), same(_retainedDatabase));
    expect(find.byType(HomePage), findsOneWidget);
    expect(DateTime.now().month, now.month,
        reason: 'Retry a run that crossed a month boundary');
    await prefs.setString('qa_run_id', qaRunId);
    binding.reportData!['final_state'] = {
      'locale': 'en',
      'theme': 'dark',
      'route': '/',
      'database': _captureMedia ? 'memory' : 'beecount.sqlite',
      'restart_persisted': !_captureMedia,
      'default_database_untouched': _captureMedia,
      'media_runtime_ms':
          _captureMedia ? mediaRuntime.elapsedMilliseconds : null,
    };
    binding.reportData!['complete'] = true;
    if (_captureMedia && kReleaseMode && Platform.isAndroid) {
      // Android logcat hard-truncates lines at 1023 bytes, so the release run
      // reports one short self-contained line per clip instead of one JSON
      // payload. Every heavy assertion already ran in-process above.
      debugPrintSynchronously(
          'QA_MEDIA_RESULT_BEGIN:${binding.reportData!['run_id']}:${binding.reportData!['package_id']}:${binding.reportData!['build_mode']}');
      for (final clip in clips) {
        debugPrintSynchronously(
            'QA_MEDIA_CLIP:${clip['name']}:${clip['started_at_ms']}:${clip['ended_at_ms']}:${clip['status']}');
      }
      debugPrintSynchronously('QA_MEDIA_RESULT_END');
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
