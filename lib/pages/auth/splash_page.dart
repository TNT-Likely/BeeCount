import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/biz/bee_icon.dart';

/// Initialization and routing remain owned by the application root.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).height < 650;
    String description(String value) =>
        value.replaceFirst(RegExp(r'^\s*•\s*'), '');
    return Scaffold(
        backgroundColor: BeeCardTheme.of(context).canvas,
        body: BeeSplashLayout(
            mark: BeeIcon(
                size: compact ? 72 : 82,
                color: Theme.of(context).colorScheme.primary),
            appName: l.splashAppName,
            slogan: l.splashSlogan,
            initializing: l.splashInitializing,
            preparing: l.splashPreparingRecords,
            securitySummary: l.splashSecuritySummary,
            securityCaption: l.splashSecurityCaption,
            securityTitle: l.splashSecurityTitle,
            securityFootnote: l.splashSecurityFootnote,
            securityFeatures: [
              BeeSplashSecurityFeature(
                  title: l.splashSecurityLocalTitle,
                  description: description(l.splashSecurityFeature1),
                  icon: 'Database'),
              BeeSplashSecurityFeature(
                  title: l.splashSecurityOpenTitle,
                  description: description(l.splashSecurityFeature2),
                  icon: 'Code'),
              BeeSplashSecurityFeature(
                  title: l.splashSecuritySyncTitle,
                  description: description(l.splashSecurityFeature3),
                  icon: 'Cloud'),
            ]));
  }
}
