import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_providers.dart';
import 'premium_skins.dart';

class PremiumSkinCanvas extends ConsumerStatefulWidget {
  const PremiumSkinCanvas({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PremiumSkinCanvas> createState() => _PremiumSkinCanvasState();
}

class _PremiumSkinCanvasState extends ConsumerState<PremiumSkinCanvas>
    with WidgetsBindingObserver {
  final _navigator = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangePlatformBrightness() {
    ref.read(premiumSkinsProvider).refreshColors();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(premiumSkinsProvider).refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(premiumSkinsProvider);
    final child = KeyedSubtree(key: _navigator, child: widget.child);
    final selected =
        ref.watch(headerSkinsEnabledProvider) ? runtime.selectedSkin : null;
    return selected?.scene(
          context,
          runtime.appearance,
          child,
          MediaQuery.viewPaddingOf(context).top,
        ) ??
        child;
  }
}
