import 'dart:async';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/settings/about_page.dart';
import 'package:beecount/pages/settings/help_center_page.dart';
import 'package:beecount/pages/settings/privacy_policy_page.dart';
import 'package:beecount/pages/settings/shortcuts_guide_page.dart';
import 'package:beecount/pages/donation/donation_page.dart';
import 'package:beecount/pages/settings/support/bindings/support_platform.dart';
import 'package:beecount/dev/component_gallery/support_sample.dart';
import 'package:beecount/pages/donation/bindings/support_donation_controls.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/update/update_dialogs.dart';
import 'package:beecount/services/platform/app_link_service.dart';
import 'package:beecount/pages/settings/support/bindings/product_promo_actions.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart'
    as web;

class _Platform extends SupportPlatform {
  bool ios = false, google = false;
  Completer<String>? versionGate;
  final opened = <Uri>[];
  final copied = <String>[];
  final products = <ProductPromo>[];
  int updates = 0, shortcuts = 0;
  bool downloaded = false;
  @override
  bool get isIOS => ios;
  @override
  bool get isGooglePlay => google;
  @override
  Future<String> version() async =>
      versionGate == null ? 'dev-9.0.0 (QA)' : await versionGate!.future;
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }

  @override
  Future<void> copy(String value) async {
    copied.add(value);
  }

  @override
  Future<void> openShortcuts() async {
    shortcuts++;
  }

  @override
  Future<void> product(
      BuildContext context, ProductPromo info, ProductPromoTexts texts) async {
    products.add(info);
    await showBeeDialog(context,
        title: info.title, child: Text(info.introBody));
  }

  @override
  Future<void> checkUpdate(BuildContext context,
      {required void Function(bool) setLoading,
      required void Function(double, String) setProgress}) async {
    updates++;
    setLoading(true);
    setProgress(0, 'QA checking');
    await Future<void>.value();
    if (!context.mounted) return;
    setLoading(false);
    setProgress(0, '');
    downloaded = await UpdateDialogs.showDownloadConfirmDialog(
        context, '9.0.1', 'QA changes');
    setLoading(false);
    setProgress(0, '');
  }
}

class _Donation extends SupportDonationGateway {
  final successes = StreamController<String>.broadcast(),
      errors = StreamController<String>.broadcast();
  bool available = true, accepted = true;
  Completer<bool>? initialization;
  int donations = 0;
  List<ProductDetails> values = [
    ProductDetails(
        id: 'coffee_small',
        title: 'QA small coffee',
        description: 'QA synthetic product',
        price: 'USD 6.00',
        rawPrice: 6,
        currencyCode: 'USD'),
    ProductDetails(
        id: 'coffee_medium',
        title: 'QA medium coffee',
        description: 'QA synthetic product',
        price: 'USD 12.00',
        rawPrice: 12,
        currencyCode: 'USD')
  ];
  @override
  Future<bool> initialize() async =>
      initialization == null ? available : await initialization!.future;
  @override
  Future<List<ProductDetails>> products() async => values;
  @override
  Stream<String> get success => successes.stream;
  @override
  Stream<String> get error => errors.stream;
  @override
  Future<bool> donate(ProductDetails product) async {
    donations++;
    return accepted;
  }

  Future<void> close() async {
    await successes.close();
    await errors.close();
  }
}

class _Delegate extends web.PlatformNavigationDelegate {
  _Delegate(super.params) : super.implementation();
  web.ProgressCallback? progress;
  web.PageEventCallback? started, finished;
  web.WebResourceErrorCallback? error;
  web.UrlChangeCallback? urlChanged;
  web.NavigationRequestCallback? request;
  @override
  Future<void> setOnProgress(web.ProgressCallback c) async {
    progress = c;
  }

  @override
  Future<void> setOnPageStarted(web.PageEventCallback c) async {
    started = c;
  }

  @override
  Future<void> setOnPageFinished(web.PageEventCallback c) async {
    finished = c;
  }

  @override
  Future<void> setOnWebResourceError(web.WebResourceErrorCallback c) async {
    error = c;
  }

  @override
  Future<void> setOnUrlChange(web.UrlChangeCallback c) async {
    urlChanged = c;
  }

  @override
  Future<void> setOnNavigationRequest(web.NavigationRequestCallback c) async {
    request = c;
  }
}

class _WebController extends web.PlatformWebViewController {
  _WebController(super.params) : super.implementation();
  Uri? loaded;
  String? current;
  bool history = false;
  int backs = 0, reloads = 0;
  web.JavaScriptMode? js;
  _Delegate? delegate;
  @override
  Future<void> setJavaScriptMode(web.JavaScriptMode mode) async {
    js = mode;
  }

  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
      web.PlatformNavigationDelegate value) async {
    delegate = value as _Delegate;
  }

  @override
  Future<void> loadRequest(web.LoadRequestParams params) async {
    loaded = params.uri;
    current = loaded.toString();
  }

  @override
  Future<String?> currentUrl() async => current;
  @override
  Future<bool> canGoBack() async => history;
  @override
  Future<void> goBack() async {
    backs++;
    history = false;
  }

  @override
  Future<void> reload() async {
    reloads++;
  }
}

class _WebWidget extends web.PlatformWebViewWidget {
  _WebWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('QA original document surface'));
}

class _Web extends web.WebViewPlatform {
  _WebController? controller;
  @override
  web.PlatformWebViewController createPlatformWebViewController(
          web.PlatformWebViewControllerCreationParams params) =>
      controller = _WebController(params);
  @override
  web.PlatformNavigationDelegate createPlatformNavigationDelegate(
          web.PlatformNavigationDelegateCreationParams params) =>
      _Delegate(params);
  @override
  web.PlatformWebViewWidget createPlatformWebViewWidget(
          web.PlatformWebViewWidgetCreationParams params) =>
      _WebWidget(params);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = AppLocalizationsEn();
  late BeeDatabase db;
  late LocalRepository repo;
  late _Platform platform;
  late _Donation donation;
  late _Web browser;
  late GlobalKey<NavigatorState> navigator;
  final launched = <String>[];
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    platform = _Platform();
    donation = _Donation();
    browser = _Web();
    web.WebViewPlatform.instance = browser;
    navigator = GlobalKey<NavigatorState>();
    launched.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async {
      final arguments = call.arguments as Map;
      launched.add(arguments['url'] as String);
      return true;
    });
  });
  tearDown(() async {
    await donation.close();
    await db.close();
  });
  Future<void> host(WidgetTester t, Widget child,
      {double scale = 1,
      Brightness brightness = Brightness.light,
      Locale locale = const Locale('en')}) async {
    await t.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
          supportPlatformProvider.overrideWithValue(platform),
          supportDonationProvider.overrideWithValue(donation)
        ],
        child: MaterialApp(
            navigatorKey: navigator,
            theme: beeTheme(brightness: brightness),
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, body) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: body!),
            home: child)));
    await t.pump();
  }

  void check(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (t) async {
      try {
        await body(t);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
      }
    });
  }

  Future<void> tap(WidgetTester t, Key key, {bool settle = true}) async {
    final finder = find.byKey(key);
    await t.ensureVisible(finder);
    await t.tap(finder);
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  check(
      'about version, story, social targets, developer debug and original products',
      (t) async {
    await host(t, const AboutPage());
    await t.pumpAndSettle();
    expect(find.text('dev-9.0.0 (QA)'), findsOneWidget);
    expect(find.byKey(const ValueKey('support-gallery')), findsOneWidget);
    await tap(t, const ValueKey('support-story'));
    expect(find.text(l.aboutDeveloperStory), findsOneWidget);
    navigator.currentState!.pop();
    await t.pumpAndSettle();
    for (final id in [
      'website',
      'github',
      'telegram',
      'xiaohongshu',
      'douyin'
    ]) {
      await tap(t, ValueKey('support-social-$id'));
    }
    expect(platform.opened.map((u) => u.toString()), [
      'https://count.beejz.com/en',
      'https://github.com/TNT-Likely/BeeCount',
      'https://t.me/beecount',
      'https://xhslink.com/m/8K1ekg7EFOq',
      'https://v.douyin.com/YG7tUweYYyQ/'
    ]);
    await tap(t, const ValueKey('support-development'));
    expect(platform.opened.last.path.endsWith('README_EN.md'), isTrue);
    await tap(t, const ValueKey('support-product-6763686675'));
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(platform.products.single.googlePlayUrl,
        contains('com.tntlikely.beeassets'));
    navigator.currentState!.pop();
    await t.pumpAndSettle();
  });
  check(
      'simplified about keeps ICP and hides Telegram; Traditional still shows it',
      (t) async {
    await host(t, const AboutPage(), locale: const Locale('zh'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-social-telegram')), findsNothing);
    expect(find.text('浙ICP备2025214907号-2A'), findsOneWidget);
    await tap(t, const ValueKey('support-development'));
    expect(platform.opened.single.path.endsWith('README_ZH.md'), isTrue);
    await host(t, const AboutPage(), locale: const Locale('zh', 'TW'));
    await t.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('support-social-telegram')), findsOneWidget);
  });
  check('about update remains original confirmation dialog and cancellation',
      (t) async {
    await host(t, const AboutPage());
    await t.pumpAndSettle();
    await tap(t, const ValueKey('support-update'));
    expect(find.byType(Dialog), findsOneWidget);
    expect(platform.updates, 1);
    navigator.currentState!.pop(false);
    await t.pumpAndSettle();
    expect(platform.downloaded, isFalse);
    expect(find.byType(AboutPage), findsOneWidget);
  });
  for (final store in ['ios', 'play']) {
    check('$store build hides check update', (t) async {
      platform.ios = store == 'ios';
      platform.google = store == 'play';
      await host(t, const AboutPage());
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('support-update')), findsNothing);
    });
  }
  check('closing about during package version load has no late state error',
      (t) async {
    platform.versionGate = Completer<String>();
    await host(t, const AboutPage());
    await host(t, const SizedBox.shrink());
    platform.versionGate!.complete('QA late');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  check('six shortcut rows copy original builders, never launch records',
      (t) async {
    platform.ios = true;
    await host(t, const ShortcutsGuidePage());
    await t.pumpAndSettle();
    final urls = [
      AppLinkBuilder.voice(),
      AppLinkBuilder.image(),
      AppLinkBuilder.camera(),
      AppLinkBuilder.newExpense(),
      AppLinkBuilder.newIncome(),
      AppLinkBuilder.newTransfer()
    ];
    for (final url in urls) {
      await tap(t, ValueKey('support-shortcut-$url'));
    }
    expect(platform.copied, urls);
    expect(platform.opened, isEmpty);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(
        find.text('beecount://add?amount=100&type=expense&category=餐饮&note=午餐'),
        findsOneWidget);
    await tap(t, const ValueKey('support-open-shortcuts'));
    expect(platform.shortcuts, 1);
  });
  check('Android shortcut steps and seven original auto-add parameters remain',
      (t) async {
    await host(t, const ShortcutsGuidePage());
    await t.pumpAndSettle();
    expect(find.text(l.androidShortcutStep4), findsOneWidget);
    expect(find.byKey(const ValueKey('support-open-shortcuts')), findsNothing);
    for (final name in [
      'amount',
      'type',
      'category',
      'note',
      'account',
      'tags',
      'date'
    ]) {
      expect(find.text(name), findsOneWidget);
    }
  });
  for (final privacy in [false, true]) {
    check(
        '${privacy ? 'privacy' : 'help'} keeps source URL, progress, main-frame failure, retry and browser fallback',
        (t) async {
      await host(
          t, privacy ? const PrivacyPolicyPage() : const HelpCenterPage());
      await t.pump();
      final webview = browser.controller!;
      final expected =
          'https://count.beejz.com/en/${privacy ? 'privacy' : 'docs/intro'}';
      expect(webview.loaded.toString(),
          startsWith('$expected?embed=1&theme=light&primary='));
      expect(webview.js, web.JavaScriptMode.unrestricted);
      webview.delegate!.progress!(50);
      await t.pump();
      expect(
          t
              .widget<LinearProgressIndicator>(
                  find.byType(LinearProgressIndicator))
              .value,
          .5);
      webview.delegate!.error!(web.WebResourceError(
          errorCode: 404,
          description: 'QA image failed',
          isForMainFrame: false));
      await t.pump();
      expect(find.text(l.helpCenterLoadFailed), findsNothing);
      webview.delegate!.error!(web.WebResourceError(
          errorCode: -1, description: 'QA main failed', isForMainFrame: true));
      await t.pump();
      expect(find.text(l.helpCenterLoadFailed), findsOneWidget);
      await tap(t, const ValueKey('support-document-browser'));
      expect(launched.last, expected);
      await tap(t, const ValueKey('support-document-retry'));
      expect(webview.reloads, 1);
      expect(find.text(l.helpCenterLoadFailed), findsNothing);
      expect(
          await webview.delegate!.request!(const web.NavigationRequest(
              url: 'https://count.beejz.com/en/docs/test', isMainFrame: true)),
          web.NavigationDecision.navigate);
      expect(
          await webview.delegate!.request!(const web.NavigationRequest(
              url: 'https://example.org/qa', isMainFrame: true)),
          web.NavigationDecision.prevent);
      expect(launched.last, 'https://example.org/qa');
    });
  }
  check(
      'help retains custom title/initial route and strips embed when opening current browser URL',
      (t) async {
    await host(
        t,
        const HelpCenterPage(
            title: 'QA custom doc',
            initialUrl:
                'https://count.beejz.com/en/docs/changelog?embed=1&theme=dark&primary=abcdef'));
    await t.pump();
    expect(find.text('QA custom doc'), findsOneWidget);
    expect(browser.controller!.loaded!.path, '/en/docs/changelog');
    browser.controller!.current =
        'https://count.beejz.com/en/docs/next?embed=1&theme=light';
    await tap(t, const ValueKey('support-document-open'));
    expect(launched.last, 'https://count.beejz.com/en/docs/next');
  });
  check('iOS help path-based pop and privacy direct pop remain distinct',
      (t) async {
    platform.ios = true;
    await host(t, const HelpCenterPage());
    await t.pump();
    expect(
        t.widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope)).canPop,
        isTrue);
    browser.controller!.delegate!.urlChanged!(
        web.UrlChange(url: 'https://count.beejz.com/en/docs/next'));
    await t.pump();
    expect(
        t.widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope)).canPop,
        isFalse);
    browser.controller!.delegate!.urlChanged!(
        web.UrlChange(url: 'https://count.beejz.com/en/docs/intro/'));
    await t.pump();
    expect(
        t.widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope)).canPop,
        isTrue);
    await host(t, const PrivacyPolicyPage());
    await t.pump();
    browser.controller!.delegate!.urlChanged!(
        web.UrlChange(url: 'https://count.beejz.com/en/privacy/next'));
    await t.pump();
    expect(
        t.widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope)).canPop,
        isTrue);
  });
  check('Android document back consumes actual web history before route pop',
      (t) async {
    await host(t, const Scaffold(body: Text('QA root')));
    navigator.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const HelpCenterPage()));
    await t.pumpAndSettle();
    browser.controller!.history = true;
    await t.pageBack();
    await t.pumpAndSettle();
    expect(browser.controller!.backs, 1);
    expect(find.byType(HelpCenterPage), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.byType(HelpCenterPage), findsNothing);
  });
  check(
      'donation original store data, duplicate guard, cancel/error and thank dialog',
      (t) async {
    await host(t, const DonationPage());
    await t.pumpAndSettle();
    expect(find.text('USD 6.00'), findsOneWidget);
    await tap(t, const ValueKey('support-donate-coffee_small'), settle: false);
    await tap(t, const ValueKey('support-donate-coffee_medium'), settle: false);
    expect(donation.donations, 1);
    donation.errors.add('');
    await t.pumpAndSettle();
    expect(find.byType(BeeDialog), findsNothing);
    await tap(t, const ValueKey('support-donate-coffee_medium'), settle: false);
    expect(donation.donations, 2);
    donation.errors.add('QA failed');
    await t.pumpAndSettle();
    expect(find.text('QA failed'), findsWidgets);
    await tap(t, const ValueKey('support-donate-coffee_small'), settle: false);
    donation.successes.add('coffee_small');
    await t.pumpAndSettle();
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(find.text(l.donationThankYouMessage('QA small coffee')),
        findsOneWidget);
  });
  check('unavailable donation and unmount during initialization remain safe',
      (t) async {
    donation.available = false;
    await host(t, const DonationPage());
    await t.pumpAndSettle();
    expect(find.text(l.donationNoProducts), findsOneWidget);
    await host(t, const SizedBox.shrink());
    donation.initialization = Completer<bool>();
    await host(t, const DonationPage());
    await host(t, const SizedBox.shrink());
    donation.initialization!.complete(true);
    await t.pumpAndSettle();
    expect(donation.successes.hasListener, isFalse);
    expect(t.takeException(), isNull);
  });
  for (final locale in [const Locale('zh'), const Locale('en')]) {
    for (final name in ['about', 'shortcuts', 'donation', 'document-error']) {
      check('${locale.languageCode} $name 320 140% dark fits', (t) async {
        t.view.physicalSize = const Size(320, 568);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final page = switch (name) {
          'about' => const AboutPage(),
          'shortcuts' => const ShortcutsGuidePage(),
          'donation' => const DonationPage(),
          _ => const HelpCenterPage()
        };
        await host(t, page,
            scale: 1.4, brightness: Brightness.dark, locale: locale);
        await t.pumpAndSettle();
        if (name == 'about') {
          await tap(t, const ValueKey('support-update'));
          expect(find.byType(AlertDialog), findsOneWidget);
          navigator.currentState!.pop(false);
          await t.pumpAndSettle();
        }
        if (name == 'document-error') {
          browser.controller!.delegate!.error!(web.WebResourceError(
              errorCode: -1, description: 'QA failure', isForMainFrame: true));
          await t.pumpAndSettle();
        }
        expect(t.takeException(), isNull);
      });
    }
  }
  check('pure support gallery invokes local callbacks without native actions',
      (t) async {
    await host(
        t, const Scaffold(body: SingleChildScrollView(child: SupportSample())));
    await t.pumpAndSettle();
    await t.tap(find.text(l.mineCheckUpdate));
    await t.pump();
    expect(find.text('QA · ${l.mineCheckUpdate}'), findsOneWidget);
    expect(platform.updates, 0);
    expect(donation.donations, 0);
    expect(platform.opened, isEmpty);
  });
  check(
      'About footer preserves changelog custom URL/title and original PrivacyPage',
      (t) async {
    await host(t, const AboutPage());
    await t.pumpAndSettle();
    await tap(t, const ValueKey('support-changelog'));
    expect(find.byType(HelpCenterPage), findsOneWidget);
    expect(browser.controller!.loaded!.path, '/en/docs/changelog');
    expect(find.text(l.aboutChangelog), findsWidgets);
    await t.pageBack();
    await t.pumpAndSettle();
    await tap(t, const ValueKey('support-privacy'));
    expect(find.byType(PrivacyPolicyPage), findsOneWidget);
    expect(browser.controller!.loaded!.path, '/en/privacy');
  });
}
