import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/theme_providers.dart';
import '../../styles/tokens.dart';
import '../../utils/website_urls.dart';
import '../../widgets/ui/ui.dart';

/// 审核兜底开关:内嵌 WebView 万一被应用商店审核拒绝,把这里改成 false
/// 重新打包提审,「使用帮助」即回退为外部浏览器打开,其余零改动。
const bool kHelpCenterInApp = true;

/// 帮助中心 — 内嵌 WebView 打开文档站(embed 模式)。
///
/// - URL 带 embed=1(站点隐藏 navbar/footer 等外链 chrome,避免审核风险)
///   + theme/primary(跟随 App 暗黑模式与主题色)+ 语言前缀(跟随 App 语言)
/// - 缓存:走 WebView 默认 HTTP 缓存 —— 文档站静态资源带 content-hash 长缓存头,
///   WKWebView(URLCache)与 Android WebView(LOAD_DEFAULT)都会落盘,无需自建
/// - 域名白名单:仅放行官网域名,外链一律转系统浏览器(审核第二道防线)
/// - 离线:加载失败显示兜底页,可重试或跳浏览器
class HelpCenterPage extends ConsumerStatefulWidget {
  const HelpCenterPage({super.key});

  @override
  ConsumerState<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends ConsumerState<HelpCenterPage> {
  WebViewController? _controller;
  String _url = '';
  int _progress = 0;
  bool _failed = false;
  // 仅 iOS 用:当前是否离开了文档首页(驱动动态 canPop)。
  // 不能用 canGoBack() 判断 —— 真机实测回到文档首页后 WKWebView 历史栈里
  // 仍有冗余条目(重定向/replaceState 噪音),canGoBack 永远 true,页面退不出去。
  // 改为直接对比 URL 路径:人在文档首页 → 放行左滑退出;不在 → 让位网页回退。
  bool _awayFromHome = false;

  static String _hex(Color c) => [c.r, c.g, c.b]
      .map((v) => ((v * 255).round() & 0xff).toRadixString(16).padLeft(2, '0'))
      .join();

  static String _normPath(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  }

  void _trackAwayFromHome(String? url) {
    if (url == null || !mounted) return;
    final away = _normPath(url) != _normPath(_url);
    if (away != _awayFromHome) setState(() => _awayFromHome = away);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初始化需要 context(locale / 暗黑 / 主题色),放 didChangeDependencies 首跑
    if (_controller != null) return;
    final locale = Localizations.localeOf(context);
    _url = WebsiteUrls.docsEmbed(
      locale,
      dark: BeeTokens.isDark(context),
      primaryHex: _hex(ref.read(primaryColorProvider)),
    );
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(BeeTokens.scaffoldBackground(context))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageStarted: (_) {
          if (mounted) setState(() => _failed = false);
        },
        onPageFinished: (url) {
          if (mounted) setState(() => _progress = 100);
          _trackAwayFromHome(url);
        },
        // SPA 的 pushState 跳转只有 onUrlChange 能跟踪到
        // (iOS 端经 WKWebView.URL 的 KVO,原生左滑回退也触发)
        onUrlChange: (change) => _trackAwayFromHome(change.url),
        onWebResourceError: (error) {
          // 只有主文档加载失败才算失败(子资源 404 不影响阅读)
          if (error.isForMainFrame == true && mounted) {
            setState(() => _failed = true);
          }
        },
        onNavigationRequest: (request) {
          // 域名白名单:站内放行,外链转系统浏览器(防止内嵌页面漏出
          // 下载/捐赠等外链,这是审核合规的第二道防线)
          final uri = Uri.tryParse(request.url);
          final host = uri?.host ?? '';
          if (host.isEmpty || host.endsWith('beejz.com')) {
            return NavigationDecision.navigate;
          }
          launchUrl(Uri.parse(request.url),
              mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(_url));
    // iOS:开启 WKWebView 原生左滑回退手势(在网页历史内回退;
    // 历史到底后 PopScope 的 canPop 才放行路由级返回)
    final platform = controller.platform;
    if (platform is WebKitWebViewController) {
      platform.setAllowsBackForwardNavigationGestures(true);
    }
    _controller = controller;
  }

  Future<void> _openInBrowser() async {
    final locale = Localizations.localeOf(context);
    // 外部打开用非 embed 的正常文档页
    final current = await _controller?.currentUrl();
    final url = (current != null && !current.contains('embed=1'))
        ? current
        : WebsiteUrls.docs(locale);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);

    return PopScope(
      // 平台分流(都是真机踩坑后的结论):
      // - Android:canPop 常 false + 回调里**实时**查询网页历史。不能用状态
      //   同步方案 —— 手势开始那刻读 canPop 有竞态,会直接退出整页
      // - iOS:动态 canPop。canPop=false 时 Flutter 路由手势让位,边缘左滑
      //   落到 WKWebView 的原生回退手势上(网页历史内回退);历史空时
      //   canPop=true,左滑正常退出页面。注意 Flutter 路由手势优先级高于
      //   WKWebView 手势,所以 iOS 不能像 Android 一样常开拦截(左滑退不出页),
      //   也不能常不拦截(左滑直接退整页)
      canPop: Platform.isIOS ? !_awayFromHome : false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final controller = _controller;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
          return;
        }
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: BeeTokens.scaffoldBackground(context),
        body: Column(
          children: [
            PrimaryHeader(
              title: l10n.mineHelp,
              showBack: true,
              compact: true,
              actions: [
                IconButton(
                  icon: Icon(Icons.open_in_browser,
                      color: BeeTokens.iconPrimary(context), size: 20),
                  tooltip: l10n.helpCenterOpenInBrowser,
                  onPressed: _openInBrowser,
                ),
              ],
            ),
            Expanded(
              child: Stack(
                children: [
                  if (_controller != null && !_failed)
                    WebViewWidget(controller: _controller!),
                  if (_failed)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off,
                              size: 48,
                              color: BeeTokens.textTertiary(context)),
                          const SizedBox(height: 12),
                          Text(
                            l10n.helpCenterLoadFailed,
                            style: TextStyle(
                                color: BeeTokens.textSecondary(context)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primary),
                            onPressed: () {
                              setState(() => _failed = false);
                              _controller?.reload();
                            },
                            child: Text(l10n.helpCenterRetry,
                                style:
                                    const TextStyle(color: Colors.white)),
                          ),
                          TextButton(
                            onPressed: _openInBrowser,
                            child: Text(l10n.helpCenterOpenInBrowser,
                                style: TextStyle(color: primary)),
                          ),
                        ],
                      ),
                    ),
                  if (!_failed && _progress < 100)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: _progress / 100,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: primary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
