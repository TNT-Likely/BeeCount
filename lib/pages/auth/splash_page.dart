import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/ui_state_providers.dart';
import '../shared/branding/bee_artwork.dart';

/// Initialization and routing remain owned by the application root.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key, this.loadError = false, this.onRetry});

  final bool loadError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).height < 650;
    String description(String value) =>
        value.replaceFirst(RegExp(r'^\s*•\s*'), '');
    return Scaffold(
        backgroundColor: BeeCardTheme.of(context).canvas,
        body: Stack(fit: StackFit.expand, children: [
          BeeSplashLayout(
              mark: BeeIcon(
                  size: compact ? 72 : 82,
                  color: Theme.of(context).colorScheme.primary),
              appName: l.splashAppName,
              slogan: l.splashSlogan,
              initializing: loadError ? l.commonError : l.splashInitializing,
              preparing: loadError ? l.commonError : l.splashPreparingRecords,
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
              ]),
          if (loadError)
            Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: FilledButton(
                            onPressed: onRetry,
                            child: Text(l.v4RecordingRetry))))),
        ]));
  }
}

/// The application stays on its startup surface until the prepared first
/// screen is ready. SplashPage itself remains a side-effect-free presentation.
class AppStartupGate extends ConsumerWidget {
  const AppStartupGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(appInitStateProvider) == AppInitState.ready) return child;
    final initialization = ref.watch(appSplashInitProvider);
    return SplashPage(
        loadError: initialization.hasError,
        onRetry: () => ref.invalidate(appSplashInitProvider));
  }
}
