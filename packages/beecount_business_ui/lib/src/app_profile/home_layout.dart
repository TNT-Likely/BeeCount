import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Keeps the journal viewport usable when the header and bottom navigation
/// leave little space. Requires a bounded height. App data and the journal's own list controller stay owned
/// by the caller; this controller only moves the compact page header.
class BeeHomeLayout extends StatelessWidget {
  const BeeHomeLayout({
    super.key,
    required this.header,
    required this.reminders,
    required this.journal,
    this.controller,
  });

  final Widget header, reminders, journal;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        assert(bounds.hasBoundedHeight);
        if (bounds.maxHeight >= 620) {
          return Column(
              children: [header, reminders, Expanded(child: journal)]);
        }
        return SingleChildScrollView(
            controller: controller,
            child: Column(children: [
              header,
              reminders,
              SizedBox(
                  height: math.max(280, bounds.maxHeight * .7), child: journal),
            ]));
      });
}
