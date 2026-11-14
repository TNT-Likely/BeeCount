import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

class BeeExecutionStep {
  const BeeExecutionStep(
      {required this.title, required this.tone, this.detail});
  final String title;
  final BeeTone tone;
  final String? detail;
}

class BeeExecutionTimeline extends StatelessWidget {
  const BeeExecutionTimeline({super.key, required this.steps});
  final List<BeeExecutionStep> steps;
  @override
  Widget build(BuildContext context) => BeeSurface(
      child: Column(
          children: steps
              .asMap()
              .entries
              .map((e) => Padding(
                  padding: EdgeInsets.only(
                      bottom: e.key == steps.length - 1 ? 0 : 16),
                  child: BeeStatus(
                      label: e.value.title,
                      detail: e.value.detail,
                      tone: e.value.tone)))
              .toList()));
}
