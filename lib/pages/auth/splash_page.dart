import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/biz/bee_icon.dart';

/// Initialization remains owned by appSplashInitProvider in the application root.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
        body: SafeArea(
            child: LayoutBuilder(
                builder: (context, bounds) => SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: bounds.maxHeight - 48),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(24)),
                                  child: Center(
                                      child: BeeIcon(
                                          size: 48,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary))),
                              const SizedBox(height: 20),
                              Text(l10n.splashAppName,
                                  style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text(l10n.splashSlogan,
                                  style: TextStyle(
                                      color: Theme.of(context).hintColor)),
                              const SizedBox(height: 32),
                              BeeSurface(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    BeeMenuRow(
                                        title: l10n.splashSecurityTitle,
                                        leading: const BeeLineIcon(
                                            'ShieldCheck',
                                            size: 20)),
                                    Text(
                                        '${l10n.splashSecurityFeature1}\n${l10n.splashSecurityFeature2}\n${l10n.splashSecurityFeature3}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            height: 1.8,
                                            color:
                                                Theme.of(context).hintColor)),
                                  ])),
                              const SizedBox(height: 28),
                              const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              const SizedBox(height: 12),
                              Text(l10n.splashInitializing,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).hintColor)),
                            ]))))));
  }
}
