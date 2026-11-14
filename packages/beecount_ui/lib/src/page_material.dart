import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../beecount_ui.dart' show BeeCardTheme;

/// One material for every card over a page scene. It never changes constraints
/// or the platform/dialog surfaces, and does not own artwork or user settings.
class BeePageMaterial extends StatelessWidget {
  const BeePageMaterial(
      {super.key,
      required this.enabled,
      required this.child,
      this.opacity = defaultOpacity,
      this.blur = defaultBlur})
      : frosted = false;

  /// Place inside the host's rounded clip, beneath its navigation controls.
  const BeePageMaterial.frosted(
      {super.key,
      required this.enabled,
      required this.child,
      this.opacity = defaultOpacity,
      this.blur = 8})
      : frosted = true;
  static const defaultOpacity = .4, defaultBlur = 0.0;
  static const minOpacity = .1, maxBlur = 16.0;
  static double normalizeOpacity(double value) =>
      value.isFinite ? value.clamp(minOpacity, 1).toDouble() : defaultOpacity;
  static double normalizeBlur(double value) =>
      value.isFinite ? value.clamp(0, maxBlur).toDouble() : defaultBlur;
  final double opacity, blur;
  final bool enabled;
  final bool frosted;
  final Widget child;

  static ThemeData theme(ThemeData source,
      {double opacity = defaultOpacity, double blur = defaultBlur}) {
    final dark = source.brightness == Brightness.dark;
    final cards = BeeCardTheme.ofTheme(source).copyWith(
      canvas: Colors.transparent,
      surfaceBlur: normalizeBlur(blur),
      surface: (dark ? const Color(0xff1d1f1f) : Colors.white)
          .withValues(alpha: normalizeOpacity(opacity)),
      soft: Colors.white.withValues(alpha: dark ? .06 : .28),
      divider: (dark ? const Color(0xffded4b7) : const Color(0xff7a673d))
          .withValues(alpha: .13),
    );
    return source.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      dividerColor: cards.divider,
      dividerTheme: source.dividerTheme.copyWith(color: cards.divider),
      cardTheme: source.cardTheme.copyWith(color: cards.surface),
      extensions: [
        ...source.extensions.values.where((e) => e is! BeeCardTheme),
        cards,
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: enabled
          ? theme(Theme.of(context), opacity: opacity, blur: frosted ? 0 : blur)
          : Theme.of(context),
      child: frosted
          ? BackdropFilter(
              enabled: enabled,
              filter: ui.ImageFilter.blur(
                  sigmaX: normalizeBlur(blur), sigmaY: normalizeBlur(blur)),
              child: child)
          : child);
}

/// Decoration-only geometry. Registers surfaces without inspecting paragraphs,
/// reading business data, rebuilding the body, or cutting holes around text.
class BeeSceneController extends ValueNotifier<Rect?> {
  BeeSceneController() : super(null);
  final canvasKey = GlobalKey();
  final _surfaces = <_SceneSurface>{};
  _SceneSurface? _anchor;
  bool _queued = false, _disposed = false;

  void _attach(_SceneSurface box) {
    _surfaces.add(box);
    scheduleMeasure();
  }

  void _detach(_SceneSurface box) {
    _surfaces.remove(box);
    scheduleMeasure();
  }

  void scheduleMeasure() {
    if (_queued || _disposed) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (_disposed) return;
      final root = canvasKey.currentContext?.findRenderObject();
      if (root is! RenderBox || !root.hasSize) return;
      Rect? first;
      _SceneSurface? firstBox;
      for (final box in _surfaces) {
        if (!box.attached || !box.hasSize || box.size.isEmpty) continue;
        var rect = MatrixUtils.transformRect(
            box.getTransformTo(root), Offset.zero & box.size);
        final scroll = box.scrollPosition;
        if (scroll != null &&
            scroll.hasPixels &&
            scroll.axis == Axis.vertical) {
          // Keep the original card's document position. Scrolling a lazy list
          // must not pull the entire scene upwards or retarget it to each row.
          rect = rect.translate(0, scroll.pixels - scroll.minScrollExtent);
        }
        // Tiny badges and nested controls are not a page's main card.
        if (rect.width < root.size.width * .6 || rect.height < 56) continue;
        if (box == _anchor) {
          first = rect;
          firstBox = box;
          break;
        }
        if (first == null || rect.top < first.top) {
          first = rect;
          firstBox = box;
        }
      }
      if (_anchor != null && !_anchor!.attached && value != null) {
        // A sliver can dispose the original card beyond cacheExtent. Retain
        // its document anchor until that card is rebuilt at the same position.
        if (first == null || (first.top - value!.top).abs() > 2) return;
      }
      _anchor = firstBox ?? _anchor;
      if (value != first) value = first;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _surfaces.clear();
    _anchor = null;
    super.dispose();
  }
}

class BeeSceneScope extends InheritedWidget {
  const BeeSceneScope(
      {super.key, required this.controller, required super.child});
  final BeeSceneController controller;
  static BeeSceneController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BeeSceneScope>()?.controller;
  @override
  bool updateShouldNotify(BeeSceneScope oldWidget) =>
      oldWidget.controller != controller;
}

class BeeSceneSurface extends SingleChildRenderObjectWidget {
  const BeeSceneSurface(
      {super.key, required this.controller, required super.child});
  final BeeSceneController? controller;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SceneSurface(controller, Scrollable.maybeOf(context)?.position);
  @override
  void updateRenderObject(
          BuildContext context, covariant RenderObject renderObject) =>
      (renderObject as _SceneSurface)
        ..controller = controller
        ..scrollPosition = Scrollable.maybeOf(context)?.position;
}

class _SceneSurface extends RenderProxyBox {
  _SceneSurface(this._controller, this.scrollPosition);
  BeeSceneController? _controller;
  ScrollPosition? scrollPosition;
  set controller(BeeSceneController? next) {
    if (_controller == next) return;
    if (attached) _controller?._detach(this);
    _controller = next;
    if (attached) _controller?._attach(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller?._attach(this);
  }

  @override
  void detach() {
    _controller?._detach(this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _controller?.scheduleMeasure();
  }
}
