import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

@immutable
class BeeSplashSecurityFeature {
  const BeeSplashSecurityFeature(
      {required this.title, required this.description, required this.icon});
  final String title, description, icon;
}

/// Startup presentation only. The application root remains the owner of readiness.
class BeeSplashLayout extends StatefulWidget {
  const BeeSplashLayout({
    super.key,
    required this.mark,
    required this.appName,
    required this.slogan,
    required this.initializing,
    required this.preparing,
    required this.securitySummary,
    required this.securityCaption,
    required this.securityTitle,
    required this.securityFeatures,
    required this.securityFootnote,
  });
  final Widget mark;
  final String appName, slogan, initializing, preparing;
  final String securitySummary,
      securityCaption,
      securityTitle,
      securityFootnote;
  final List<BeeSplashSecurityFeature> securityFeatures;

  @override
  State<BeeSplashLayout> createState() => _BeeSplashLayoutState();
}

class _BeeSplashLayoutState extends State<BeeSplashLayout> {
  bool _securityOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), accent = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurface.withValues(alpha: .5);
    return Stack(children: [
      ExcludeSemantics(
          excluding: _securityOpen,
          child: SafeArea(child: LayoutBuilder(builder: (context, bounds) {
            final compact = MediaQuery.sizeOf(context).height < 650;
            final large = MediaQuery.textScalerOf(context).scale(1) > 1.2;
            final markSize = compact ? 78.0 : 92.0;
            final top = compact && large
                ? 49.0
                : MediaQuery.sizeOf(context).height * (compact ? .145 : .225);
            return Stack(children: [
              Positioned.fill(
                  child: BeeTrailBackdrop(
                      focalPoint:
                          Offset(bounds.maxWidth / 2, top + markSize / 2))),
              SingleChildScrollView(
                  child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: bounds.maxHeight),
                      child: IntrinsicHeight(
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(children: [
                                SizedBox(height: top),
                                SizedBox.square(
                                    dimension: markSize,
                                    child: Center(child: widget.mark)),
                                SizedBox(height: compact ? 17 : 22),
                                Text(widget.appName,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: compact ? 27 : 30,
                                        height: 1.28,
                                        letterSpacing: -.8,
                                        fontWeight: FontWeight.w600)),
                                SizedBox(height: compact ? 7 : 9),
                                Text(widget.slogan,
                                    style: TextStyle(
                                        fontSize: 13,
                                        height: 1.5,
                                        letterSpacing: 1.5,
                                        color: muted)),
                                SizedBox(
                                    height: compact ? (large ? 15 : 18) : 23),
                                Container(
                                    width: 34,
                                    height: 2,
                                    decoration: BoxDecoration(
                                        color: accent.withValues(alpha: .65),
                                        borderRadius:
                                            BorderRadius.circular(2))),
                                SizedBox(
                                    height: compact ? (large ? 24 : 30) : 46),
                                ConstrainedBox(
                                    constraints: BoxConstraints(
                                        minHeight: compact ? 70 : 78),
                                    child: Column(children: [
                                      Semantics(
                                          liveRegion: true,
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const BeeActivityIndicator(),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                    child: Text(
                                                        widget.initializing,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            height: 1.5,
                                                            color: muted)))
                                              ])),
                                      const SizedBox(height: 10),
                                      Text(widget.preparing,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 10,
                                              height: 1.65,
                                              color: muted))
                                    ])),
                                const Spacer(),
                                Padding(
                                    padding: EdgeInsets.only(
                                        top: compact ? (large ? 5 : 13) : 22,
                                        bottom: compact ? 8 : 15),
                                    child: Column(children: [
                                      TextButton(
                                          onPressed: () => setState(
                                              () => _securityOpen = true),
                                          style: TextButton.styleFrom(
                                              foregroundColor: muted,
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(44, 44)),
                                          child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                BeeLineIcon('ShieldCheck',
                                                    size: 13, color: muted),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                    child: Text(
                                                        widget.securitySummary,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            height: 1.5)))
                                              ])),
                                      Text(widget.securityCaption,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 10,
                                              height: 1.5,
                                              color: muted))
                                    ]))
                              ])))))
            ]);
          }))),
      if (_securityOpen)
        Positioned.fill(
            child: BeeLocalSheet(
                title: widget.securityTitle,
                onClose: () => setState(() => _securityOpen = false),
                child: BeeSplashSecurityContent(
                    features: widget.securityFeatures,
                    footnote: widget.securityFootnote)))
    ]);
  }
}

class BeeSplashSecurityContent extends StatelessWidget {
  const BeeSplashSecurityContent(
      {super.key, required this.features, required this.footnote});
  final List<BeeSplashSecurityFeature> features;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: .5);
    return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final feature in features)
            Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: BeeCardTheme.of(context).divider))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: BeeLineIcon(feature.icon,
                              size: 20,
                              color: Color.lerp(
                                  scheme.primary, Colors.black, .4))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(feature.title,
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(feature.description,
                                style: TextStyle(
                                    fontSize: 11, height: 1.7, color: muted))
                          ]))
                    ])),
          const SizedBox(height: 16),
          Text(footnote,
              style: TextStyle(fontSize: 10, height: 1.7, color: muted))
        ]));
  }
}
