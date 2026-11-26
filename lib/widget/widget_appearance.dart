import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../l10n/app_localizations.dart';

/// Stable tags shared by Flutter, WidgetKit and the Android launcher.
Locale resolveWidgetLocale(Iterable<Locale> preferences) {
  for (final locale in preferences) {
    if (locale.languageCode == 'zh') {
      final traditional = locale.scriptCode == 'Hant' ||
          (locale.scriptCode != 'Hans' &&
              const {'TW', 'HK', 'MO'}.contains(locale.countryCode));
      return traditional ? const Locale('zh', 'TW') : const Locale('zh');
    }
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
  }
  return const Locale('en');
}

typedef WidgetRenderResult = ({String path, bool complete});

typedef WidgetVariant = ({Locale locale, Brightness brightness});

extension on WidgetVariant {
  String get key => '${locale.toLanguageTag()}.${brightness.name}';
}

class WidgetAppearance {
  final Locale? explicitLocale;
  final ThemeMode theme;
  final WidgetVariant current;

  WidgetAppearance({
    required this.explicitLocale,
    required this.theme,
    required List<Locale> systemLocales,
    required Brightness systemBrightness,
  }) : current = (
          locale: resolveWidgetLocale(
              explicitLocale == null ? systemLocales : [explicitLocale]),
          brightness: switch (theme) {
            ThemeMode.light => Brightness.light,
            ThemeMode.dark => Brightness.dark,
            ThemeMode.system => systemBrightness,
          },
        );

  Iterable<WidgetVariant> get variants sync* {
    yield current;
    final locales = explicitLocale == null
        ? AppLocalizations.supportedLocales
        : [current.locale];
    final brightnesses =
        theme == ThemeMode.system ? Brightness.values : [current.brightness];
    for (final locale in locales) {
      for (final brightness in brightnesses) {
        final variant = (locale: locale, brightness: brightness);
        if (variant != current) yield variant;
      }
    }
  }
}

/// One committed image set per widget size. Different data uses the other
/// file slot so an interrupted update cannot overwrite the published artwork.
Future<bool> cacheWidgetAppearance({
  required String imageKey,
  required String fingerprint,
  required WidgetAppearance appearance,
  required Future<WidgetRenderResult> Function(
          String fileKey, WidgetVariant variant)
      render,
}) async {
  final manifestKey = '$imageKey.appearance.v1';
  final previousJson = await HomeWidget.getWidgetData<String>(manifestKey);
  Map<String, dynamic> previous = {};
  if (previousJson != null) {
    try {
      final parsed = jsonDecode(previousJson);
      if (parsed is Map<String, dynamic>) previous = parsed;
    } on FormatException {
      // Rebuild interrupted or unrecognised manifests from the current ledger.
    }
  }

  final sameData = previous['fingerprint'] == fingerprint;
  final previousSlot = previous['slot'] == 1 ? 1 : 0;
  final slot = sameData ? previousSlot : 1 - previousSlot;
  final images = <String, String>{};
  if (sameData && previous['images'] is Map) {
    for (final entry in (previous['images'] as Map).entries) {
      if (entry.key is String && entry.value is String) {
        images[entry.key as String] = entry.value as String;
      }
    }
  }

  var rendered = false;
  String? firstReadyPath;
  String? fallbackCard;
  for (final variant in appearance.variants) {
    final path = images[variant.key];
    if (path != null) {
      final file = await File(path).stat();
      if (file.type == FileSystemEntityType.file && file.size > 0) {
        firstReadyPath ??= path;
        continue;
      }
    }
    images.remove(variant.key);
    final result = await render('$imageKey.$slot.${variant.key}', variant);
    rendered = true;
    if (result.complete) {
      images[variant.key] = result.path;
      firstReadyPath ??= result.path;
    } else {
      fallbackCard ??= result.path;
    }
  }

  final fallback =
      images[appearance.current.key] ?? firstReadyPath ?? fallbackCard!;
  final json = jsonEncode({
    'locale': appearance.explicitLocale == null
        ? 'system'
        : appearance.current.locale.toLanguageTag(),
    'theme': appearance.theme.name,
    'images': images,
    'fallback': fallback,
    'fingerprint': fingerprint,
    'slot': slot,
  });
  if (json == previousJson) return rendered;
  // Legacy readers still use the original key (including "widgetImage").
  if (await HomeWidget.saveWidgetData(imageKey, fallback) != true) {
    throw StateError('Failed to save $imageKey');
  }
  if (await HomeWidget.saveWidgetData(manifestKey, json) != true) {
    throw StateError('Failed to publish $manifestKey');
  }
  return true;
}
