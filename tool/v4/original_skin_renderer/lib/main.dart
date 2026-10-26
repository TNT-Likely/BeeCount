// Study-only Flutter entrypoint. No BeeCount App, database, Cloud or AI imports.
import 'dart:async';
import 'dart:convert';
// Flutter 3.27 / Dart 3.6 standalone web renderer; no extra runtime packages.
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'header_skins.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OriginalSkinRenderer());
}

class OriginalSkinRenderer extends StatefulWidget {
  const OriginalSkinRenderer({super.key});
  @override
  State<OriginalSkinRenderer> createState() => _OriginalSkinRendererState();
}

class _OriginalSkinRendererState extends State<OriginalSkinRenderer> {
  final params = Uri.base.queryParameters;
  late String skin =
      params['skin'] == 'anniv_cake' ? 'anniv_cake' : 'anniversary';
  late bool dark = params['dark'] == '1';
  late String kind = ['application', 'tab'].contains(params['kind'])
      ? params['kind']!
      : 'header';
  Rect? headerSlot, headerArtRect, tabSlot;
  double headerRadius = 0, tabRadius = 28;
  Color tabBackground = Colors.transparent;
  bool headerVisible = true, tabVisible = true;
  late String motion = params['motion'] ?? 'play';
  late bool systemReduced =
      html.window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  late final String instance = params['instance'] ?? 'reference';
  late final StreamSubscription<html.MessageEvent> subscription;
  int frames = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      frames++;
    });
    subscription = html.window.onMessage.listen((event) {
      if (event.origin != html.window.location.origin || event.data is! String)
        return;
      Object? decoded;
      try {
        decoded = jsonDecode(event.data as String);
      } catch (_) {
        return;
      }
      if (decoded is! Map || decoded['type'] != 'beecount-original-skin')
        return;
      final payload = decoded;
      if (payload['command'] == 'probe') {
        report('probe');
        return;
      }
      setState(() {
        if (['anniversary', 'anniv_cake'].contains(payload['skin']))
          skin = payload['skin'] as String;
        if (payload['dark'] is bool) dark = payload['dark'] as bool;
        if (['application', 'tab', 'header'].contains(payload['kind']))
          kind = payload['kind'] as String;
        Rect? slot(Object? value) {
          if (value is! List ||
              value.length != 4 ||
              value.any((v) => v is! num || !v.isFinite || v.abs() > 10000))
            return null;
          return Rect.fromLTWH(
              (value[0] as num).toDouble(),
              (value[1] as num).toDouble(),
              (value[2] as num).toDouble().clamp(0, 2000),
              (value[3] as num).toDouble().clamp(0, 2000));
        }

        headerSlot = slot(payload['headerSlot']) ?? headerSlot;
        headerArtRect = slot(payload['headerArtRect']);
        tabSlot = slot(payload['tabSlot']) ?? tabSlot;
        if (payload['headerRadius'] is num)
          headerRadius =
              (payload['headerRadius'] as num).toDouble().clamp(0, 100);
        if (payload['tabRadius'] is num)
          tabRadius = (payload['tabRadius'] as num).toDouble().clamp(0, 100);
        if (payload['tabBackground'] is int)
          tabBackground = Color(payload['tabBackground'] as int);
        if (payload['headerVisible'] is bool)
          headerVisible = payload['headerVisible'] as bool;
        if (payload['tabVisible'] is bool)
          tabVisible = payload['tabVisible'] as bool;
        if (['play', 'paused', 'off', 'reduced'].contains(payload['motion']))
          motion = payload['motion'] as String;
        if (payload['systemReduced'] is bool)
          systemReduced = payload['systemReduced'] as bool;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => report('updated'));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => report('ready'));
  }

  void report(String event) {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final message = jsonEncode({
      'type': 'beecount-original-skin-status',
      'event': event,
      'instance': instance,
      'source': '3.9.0',
      'skin': skin,
      'kind': kind,
      'dark': dark,
      'motion': motion,
      'systemReduced': systemReduced,
      'frames': frames,
      'width': view.physicalSize.width / view.devicePixelRatio,
      'height': view.physicalSize.height / view.devicePixelRatio,
      'periodSeconds': kind == 'tab' ? (skin == 'anniv_cake' ? 9 : 7) : 10,
      'headerPeriodSeconds': 10,
      'tabPeriodSeconds': skin == 'anniv_cake' ? 9 : 7,
      'headerCanvas': [398, 208],
      'headerSlot': headerSlot == null
          ? null
          : [
              headerSlot!.left,
              headerSlot!.top,
              headerSlot!.width,
              headerSlot!.height
            ],
      'headerVisible': headerVisible,
      'headerArtRect': headerArtRect == null
          ? null
          : [
              headerArtRect!.left,
              headerArtRect!.top,
              headerArtRect!.width,
              headerArtRect!.height
            ],
      'tabVisible': tabVisible,
    });
    html.window.parent?.postMessage(message, html.window.location.origin);
    if (html.window.top != html.window.parent)
      html.window.top?.postMessage(message, html.window.location.origin);
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  Widget header() => ColoredBox(
        color: dark ? Colors.black : originalPrimary(skin),
        child: originalSkin(skin, dark, false),
      );
  Decoration carrier(Rect rect, Rect art) {
    if (skin != 'anniv_cake') {
      return BoxDecoration(color: dark ? Colors.black : originalPrimary(skin));
    }
    // Only the empty carrier continues the original base palette. The complete
    // original Painter remains untouched in its own 398x208 logical canvas.
    final top = (art.top / rect.height).clamp(0.0, 1.0);
    final bottom = ((art.top + art.height) / rect.height).clamp(top, 1.0);
    return BoxDecoration(
        gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0xFF1A1004),
              Color(0xFF1A1004)
            ]
          : const [
              Color(0xFFFFFBF0),
              Color(0xFFFFFBF0),
              Color(0xFFFFF0D2),
              Color(0xFFFFE0AE),
              Color(0xFFFFE0AE)
            ],
      stops: dark
          ? [0, top, bottom, 1]
          : [0, top, top + (bottom - top) * .6, bottom, 1],
    ));
  }

  Widget positionedHeader(Rect rect) {
    final art = headerArtRect ?? Rect.fromLTWH(0, 0, rect.width, rect.height);
    return Positioned.fromRect(
      rect: rect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(headerRadius),
        child: DecoratedBox(
          decoration: carrier(rect, art),
          child: TickerMode(
            enabled: headerVisible,
            child: Stack(children: [
              Positioned.fromRect(
                rect: art,
                child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: 398, height: 208, child: header())),
              )
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    return MediaQuery(
      data: MediaQueryData.fromView(view).copyWith(
        padding: EdgeInsets.zero,
        disableAnimations:
            systemReduced || motion == 'off' || motion == 'reduced',
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: TickerMode(
          enabled: motion != 'paused',
          child: kind == 'application'
              ? Stack(children: [
                  if (headerSlot case final rect?) positionedHeader(rect),
                  if (tabSlot case final rect?)
                    Positioned.fromRect(
                        rect: rect,
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(tabRadius),
                            child: ColoredBox(
                                color: tabBackground,
                                child: TickerMode(
                                    enabled: tabVisible,
                                    child: originalSkin(skin, dark, true))))),
                ])
              : kind == 'tab'
                  ? originalSkin(skin, dark, true)
                  : header(),
        ),
      ),
    );
  }
}
