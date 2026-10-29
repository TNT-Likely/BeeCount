import 'package:flutter/material.dart';

class BeeCategoryChoice {
  const BeeCategoryChoice(
      {required this.id,
      required this.label,
      required this.icon,
      this.children = const [],
      this.enabled = true,
      this.detail});
  final String id, label;
  final Widget icon;
  final List<BeeCategoryChoice> children;
  final bool enabled;
  final String? detail;
}
