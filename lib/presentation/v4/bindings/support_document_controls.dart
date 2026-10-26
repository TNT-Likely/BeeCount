import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/theme_providers.dart';
import '../../../styles/tokens.dart';
import '../../../utils/website_urls.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/support.dart';
import 'support_frame.dart';
import 'support_platform.dart';

/// 帮助中心 — 内嵌 WebView 打开文档站(embed 模式)。
///
/// - URL 带 embed=1(站点隐藏 navbar/footer 等外链 chrome,避免审核风险)
///   + theme/primary(跟随 App 暗黑模式与主题色)+ 语言前缀(跟随 App 语言)
/// - 缓存:走 WebView 默认 HTTP 缓存 —— 文档站静态资源带 content-hash 长缓存头,
///   WKWebView(URLCache)与 Android WebView(LOAD_DEFAULT)都会落盘,无需自建
/// - 域名白名单:仅放行官网域名,外链一律转系统浏览器(审核第二道防线)
/// - 离线:加载失败显示兜底页,可重试或跳浏览器
class SupportDocumentControls extends ConsumerStatefulWidget {
  const SupportDocumentControls(
      {super.key, this.initialUrl, this.title, this.privacy = false});
  final bool privacy;

  /// 可选:指定初始打开的文档 URL(应为本站 embed 模式链接)。不传则打开文档
  /// 首页(intro)。登录页「注册指引」用它按当前云后端直达对应文档。
  final String? initialUrl;

  /// 可选:自定义页面标题(不传用「使用帮助」)。复用本页打开其它文档(如更新
  /// 日志)时传对应标题。
  final String? title;

  @override
  ConsumerState<SupportDocumentControls> createState() =>
      _SupportDocumentControlsState();
}

class _SupportDocumentControlsState
    extends ConsumerState<SupportDocumentControls> {
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
    if (widget.privacy) return;
    final away = _normPath(url) != _normPath(_url);
    if (away != _awayFromHome) setState(() => _awayFromHome = away);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初始化需要 context(locale / 暗黑 / 主题色),放 didChangeDependencies 首跑
    if (_controller != null) return;
    final locale = Localizations.localeOf(context);
    _url = widget.initialUrl ??
        (widget.privacy ? WebsiteUrls.privacy : WebsiteUrls.docsEmbed)(
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
    if (widget.privacy) {
      final lang = locale.languageCode == 'zh' ? '' : '/en';
      await launchUrl(Uri.parse('${WebsiteUrls.baseUrl}$lang/privacy'),
          mode: LaunchMode.externalApplication);
      return;
    }
    final current = await _controller?.currentUrl();
    // 外部打开用非 embed 的正常文档页:当前是 embed 链接(初始页或站内跳转)就
    // 去掉 query 还原正常文档 URL;拿不到当前 URL 才兜底文档首页。
    final String url;
    if (current == null) {
      url = WebsiteUrls.docs(locale);
    } else if (current.contains('embed=1')) {
      url = current.split('?').first;
    } else {
      url = current;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      // 平台分流(都是真机踩坑后的结论):
      // - Android:canPop 常 false + 回调里**实时**查询网页历史。不能用状态
      //   同步方案 —— 手势开始那刻读 canPop 有竞态,会直接退出整页
      // - iOS:动态 canPop。canPop=false 时 Flutter 路由手势让位,边缘左滑
      //   落到 WKWebView 的原生回退手势上(网页历史内回退);历史空时
      //   canPop=true,左滑正常退出页面。注意 Flutter 路由手势优先级高于
      //   WKWebView 手势,所以 iOS 不能像 Android 一样常开拦截(左滑退不出页),
      //   也不能常不拦截(左滑直接退整页)
      canPop: ref.watch(supportPlatformProvider).isIOS
          ? (widget.privacy || !_awayFromHome)
          : false,
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
      child: SupportFrame(
        title: widget.title ??
            (widget.privacy ? l10n.aboutPrivacyPolicy : l10n.mineHelp),
        actions: widget.privacy
            ? const []
            : [
                BeeIconButton(
                    key: const ValueKey('support-document-open'),
                    label: l10n.helpCenterOpenInBrowser,
                    icon: const BeeLineIcon('ExternalLink', size: 20),
                    onPressed: _openInBrowser)
              ],
        body: BeeSupportDocument(
          view: _controller == null
              ? const SizedBox.shrink()
              : WebViewWidget(controller: _controller!),
          progress: _progress,
          failed: _failed,
          failureLabel: l10n.helpCenterLoadFailed,
          retryLabel: l10n.helpCenterRetry,
          browserLabel: l10n.helpCenterOpenInBrowser,
          onRetry: () {
            setState(() => _failed = false);
            _controller?.reload();
          },
          onBrowser: _openInBrowser,
        ),
      ),
    );
  }
}
