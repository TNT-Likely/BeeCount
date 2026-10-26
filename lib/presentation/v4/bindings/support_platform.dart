import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/system/update_service.dart';
import '../../../services/system/logger_service.dart';
import '../../../widgets/biz/product_promo_card.dart';

final supportPlatformProvider =
    Provider<SupportPlatform>((ref) => const SupportPlatform());

/// App-only adapter. The real URLs, update flow and product dialogs stay intact.
class SupportPlatform {
  const SupportPlatform();
  bool get isIOS => Platform.isIOS;
  bool get isGooglePlay =>
      const bool.fromEnvironment('GOOGLE_PLAY', defaultValue: false);
  Future<String> version() async {
    final p = await PackageInfo.fromPlatform();
    const ciVersion = String.fromEnvironment('CI_VERSION');
    final version = ciVersion.isNotEmpty ? ciVersion : 'dev-${p.version}';
    return version.startsWith('dev-') ? '$version (${p.buildNumber})' : version;
  }

  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));
  Future<void> openShortcuts() async {
    final uri = Uri.parse('shortcuts://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<bool> open(Uri url) async {
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
        return true;
      }
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
        return true;
      }
      logger.error('AboutPage', '无法打开URL: $url');
      return false;
    } catch (e) {
      logger.error('AboutPage', '打开URL失败: $url', e);
      return false;
    }
  }

  Future<void> checkUpdate(BuildContext context,
          {required void Function(bool) setLoading,
          required void Function(double, String) setProgress}) =>
      UpdateService.checkUpdateWithUI(context,
          setLoading: setLoading, setProgress: setProgress);
  Future<void> product(
          BuildContext context, ProductPromo info, ProductPromoTexts texts) =>
      ProductPromoLauncher.open(context, info, texts);
}
