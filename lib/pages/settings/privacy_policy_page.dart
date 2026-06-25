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

/// 隐私政策 — 内嵌 WebView 打开官网 /privacy(embed 模式)。
///
/// 与帮助中心同款做法:embed 隐藏 navbar/footer 外链 chrome(审核风险)、
/// 域名白名单(外链转系统浏览器)、跟随 App 暗黑模式与主题色、加载失败兜底。
class PrivacyPolicyPage extends ConsumerStatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  ConsumerState<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends ConsumerState<PrivacyPolicyPage> {
  WebViewController? _controller;
  String _url = '';
  int _progress = 0;
  bool _failed = false;

  static String _hex(Color c) => [c.r, c.g, c.b]
      .map((v) => ((v * 255).round() & 0xff).toRadixString(16).padLeft(2, '0'))
      .join();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final locale = Localizations.localeOf(context);
    _url = WebsiteUrls.privacy(
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
        onPageFinished: (_) {
          if (mounted) setState(() => _progress = 100);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() => _failed = true);
          }
        },
        onNavigationRequest: (request) {
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
    final platform = controller.platform;
    if (platform is WebKitWebViewController) {
      platform.setAllowsBackForwardNavigationGestures(true);
    }
    _controller = controller;
  }

  Future<void> _openInBrowser() async {
    final locale = Localizations.localeOf(context);
    final lang = locale.languageCode == 'zh' ? '' : '/en';
    await launchUrl(Uri.parse('${WebsiteUrls.baseUrl}$lang/privacy'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);

    return PopScope(
      // iOS:单页隐私政策无 SPA 历史,直接放行退出;
      // Android:先在网页历史内回退,到底再退出路由。
      canPop: Platform.isIOS,
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
              title: l10n.aboutPrivacyPolicy,
              showBack: true,
              compact: true,
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
                              size: 48, color: BeeTokens.textTertiary(context)),
                          const SizedBox(height: 12),
                          Text(l10n.helpCenterLoadFailed,
                              style: TextStyle(
                                  color: BeeTokens.textSecondary(context))),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primary),
                            onPressed: () {
                              setState(() => _failed = false);
                              _controller?.reload();
                            },
                            child: Text(l10n.helpCenterRetry,
                                style: const TextStyle(color: Colors.white)),
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
