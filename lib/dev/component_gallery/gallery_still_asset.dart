import 'package:flutter/material.dart';

/// Static preview assets must resolve even while the catalogue tickers are
/// paused. Image's normal lifecycle defers its stream under a muted TickerMode.
class GalleryStillAsset extends StatefulWidget {
  const GalleryStillAsset(this.asset,
      {super.key, required this.label, this.width = 24, this.height = 24});
  final String asset, label;
  final double width, height;
  @override
  State<GalleryStillAsset> createState() => _GalleryStillAssetState();
}

class _GalleryStillAssetState extends State<GalleryStillAsset> {
  ImageStream? stream;
  ImageInfo? frame;
  late final listener = ImageStreamListener((image, synchronous) {
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() {
      frame?.dispose();
      frame = image;
    });
  });
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    resolve();
  }

  @override
  void didUpdateWidget(covariant GalleryStillAsset oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) resolve();
  }

  void resolve() {
    final next = AssetImage(widget.asset)
        .resolve(createLocalImageConfiguration(context));
    if (next.key == stream?.key) return;
    stream?.removeListener(listener);
    stream = next;
    stream!.addListener(listener);
  }

  @override
  void dispose() {
    stream?.removeListener(listener);
    frame?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      image: true,
      label: widget.label,
      child: ExcludeSemantics(
          child: RawImage(
              image: frame?.image,
              scale: frame?.scale ?? 1,
              width: widget.width,
              height: widget.height,
              fit: BoxFit.contain)));
}
