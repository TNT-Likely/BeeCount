import 'dart:async';
import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/data/full_data_export_page.dart';
import 'package:beecount/pages/settings/data_management_page.dart';
import 'package:beecount/services/export/full_data_export_service.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Export extends FullDataExportService {
  _Export(super.db);
  Completer<FullDataExportResult> next = Completer();
  int calls = 0;

  @override
  Future<FullDataExportResult> export({AppLocalizations? l10n}) {
    calls++;
    return next.future;
  }
}

void main() {
  testWidgets('data management opens ZIP export and reports missing files',
      (tester) async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final exporter = _Export(db);
    await tester.pumpWidget(ProviderScope(
      overrides: [fullDataExportServiceProvider.overrideWithValue(exporter)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: beeTheme(),
        home: const DataManagementPage(),
      ),
    ));
    expect(find.byType(FullDataExportEntry), findsOneWidget);
    await tester.tap(find.text('Export all data'));
    await tester.pumpAndSettle();
    expect(find.byType(FullDataExportPage), findsOneWidget);
    await tester.tap(find.text('Generate ZIP'));
    await tester.pump();
    expect(find.text('Generating ZIP…'), findsOneWidget);
    await tester.tap(find.text('Generating ZIP…'));
    expect(exporter.calls, 1);
    exporter.next
        .complete(FullDataExportResult(File('/tmp/test.zip'), 2, 3, 1));
    await tester.pumpAndSettle();
    expect(find.text('ZIP ready · 2 ledgers · 3 image files'), findsOneWidget);
    expect(find.textContaining('One file is unavailable'), findsOneWidget);
    expect(find.text('Save or share ZIP'), findsOneWidget);
  });
}
