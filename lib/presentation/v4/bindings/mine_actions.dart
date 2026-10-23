import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_review/in_app_review.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/system/logger_service.dart';

Future<bool> tryOpenMineUrl(Uri url) async {
  try {
    // 方式1: 默认外部应用打开
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return true;
    }

    // 方式2: 浏览器内打开
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
      return true;
    }

    // 方式3: 平台默认方式
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
      return true;
    }

    logger.error('MinePage', '无法打开URL: $url');
    return false;
  } catch (e) {
    logger.error('MinePage', '打开URL失败: $url', e);
    return false;
  }
}

/// 显示 GitHub Star 引导弹窗
void showMineGitHubStarGuide(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final screenHeight = MediaQuery.of(context).size.height;

  showDialog(
    context: context,
    builder: (context) => BeeDialog(
      title: Text(l10n.githubStarGuideTitle),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.5,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.githubStarGuideContent,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              // 引导图片
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/github_star_guide.png',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            tryOpenMineUrl(Uri.parse('https://github.com/TNT-Likely/BeeCount'));
          },
          child: Text(l10n.githubStarGuideButton),
        ),
      ],
    ),
  );
}

/// 请求应用评分
///
/// iOS系统对原生评分弹窗有限制：
/// 1. 每365天最多弹出3次
/// 2. 模拟器上不显示
/// 3. 用户可在系统设置中禁用
///
/// 因此直接打开App Store评分页面更可靠
Future<void> rateMineApp(BuildContext context) async {
  try {
    final InAppReview inAppReview = InAppReview.instance;

    // 直接打开应用商店评分页面（更可靠，不受系统限制）
    if (Platform.isIOS) {
      await inAppReview.openStoreListing(
        appStoreId: '6754611670', // BeeCount的App Store ID
      );
      logger.info('MinePage', '已打开App Store评分页面');
    } else {
      // Android会自动打开Google Play（如果已上架）
      await inAppReview.openStoreListing();
      logger.info('MinePage', '已打开Google Play评分页面');
    }
  } catch (e) {
    logger.error('MinePage', '打开评分失败', e);
    // 失败时不显示错误提示，静默失败
  }
}
