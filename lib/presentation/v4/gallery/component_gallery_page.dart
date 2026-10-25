import '../bindings/import_context_preview.dart';
import '../bindings/export_preview.dart';
import '../bindings/recurring_editor_preview.dart';
import '../bindings/annual_report_preview.dart';
import '../bindings/cloud_configuration_preview.dart';
import '../bindings/recurring_bills_preview.dart';
import '../bindings/ai_conversation_preview.dart';
import '../bindings/execution_depth_preview.dart';
import '../bindings/ai_prompt_preview.dart';
import '../bindings/ai_provider_preview.dart';
import '../bindings/ai_settings_preview.dart';
import '../bindings/smart_billing_preview.dart';
import '../bindings/analytics_preview.dart';
import '../bindings/calendar_preview.dart';
import '../bindings/budget_editor_preview.dart';
import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'foundation_page.dart';
import 'page_migration_gallery.dart';
import 'business_page.dart';
import '../bindings/exchange_rate_preview.dart';
import '../bindings/budget_preview.dart';
import '../bindings/live_business_preview.dart';
import '../bindings/tag_library_preview.dart';
import '../bindings/reminder_preview.dart';
import '../bindings/skin_preview.dart';
import '../bindings/file_workflow_preview.dart';
import '../bindings/attachment_library_preview.dart';
import '../bindings/category_migration_preview.dart';
import '../bindings/note_history_preview.dart';

/// Debug route inside BeeCount's existing navigator, theme and localization scope.
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key, this.enableLiveData = true});
  final bool enableLiveData;
  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  int tab = 0;
  Brightness? brightness;
  Color? accent;
  bool motionPaused = false;
  @override
  Widget build(BuildContext context) {
    final host = Theme.of(context);
    return Theme(
        data: beeTheme(
            brightness: brightness ?? host.brightness,
            accent: accent ?? host.colorScheme.primary),
        child: Builder(
            builder: (context) => Scaffold(
                  appBar: AppBar(
                      title: Text(tab == 0 ? '基础组件验收' : '业务组件验收'),
                      actions: [
                        BeeIconButton(
                            label: '页面迁移验收',
                            icon: const Icon(Icons.pages_outlined),
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const PageMigrationGallery()))),
                        PopupMenuButton<Object>(
                            tooltip: '主题色与动效',
                            onSelected: (v) => setState(() {
                                  if (v is Color) {
                                    accent = v;
                                  } else if (v == 'motion') {
                                    motionPaused = !motionPaused;
                                  }
                                }),
                            itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: Color(0xfffacb16),
                                      child: Text('蜜蜂黄')),
                                  const PopupMenuItem(
                                      value: Color(0xff49a396),
                                      child: Text('薄荷绿')),
                                  const PopupMenuItem(
                                      value: Color(0xff7771db),
                                      child: Text('鸢尾紫')),
                                  const PopupMenuDivider(),
                                  PopupMenuItem(
                                      value: 'motion',
                                      child: Text(
                                          motionPaused ? '播放示例动效' : '暂停示例动效'))
                                ]),
                        IconButton(
                            tooltip: '切换深浅色',
                            icon: const Icon(Icons.brightness_6_outlined),
                            onPressed: () => setState(() => brightness =
                                (brightness ?? host.brightness) ==
                                        Brightness.light
                                    ? Brightness.dark
                                    : Brightness.light))
                      ]),
                  body: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: IndexedStack(index: tab, children: [
                            TickerMode(
                                key: const ValueKey(
                                    'gallery-foundation-tickers'),
                                enabled: tab == 0 && !motionPaused,
                                child: const FoundationAcceptancePage()),
                            TickerMode(
                                key: const ValueKey('gallery-business-tickers'),
                                enabled: tab == 1 && !motionPaused,
                                child: BusinessAcceptancePage(
                                    importContextData: widget.enableLiveData
                                        ? const LiveImportContextPreview()
                                        : null,
                                    exportData: widget.enableLiveData
                                        ? const ExportPreview()
                                        : null,
                                    recurringEditorData: widget.enableLiveData
                                        ? const RecurringEditorPreview()
                                        : null,
                                    annualReportData: widget.enableLiveData
                                        ? const LiveAnnualReportPreview()
                                        : null,
                                    cloudConfigurationData: widget.enableLiveData
                                        ? const LiveCloudConfigurationPreview()
                                        : null,
                                    recurringBillData: widget.enableLiveData
                                        ? const LiveRecurringBillsPreview()
                                        : null,
                                    aiConversationData: widget.enableLiveData
                                        ? const LiveAIConversationPreview()
                                        : null,
                                    executionDepthData: widget.enableLiveData
                                        ? const LiveExecutionDepthPreview()
                                        : null,
                                    aiPromptData: widget.enableLiveData
                                        ? const LiveAIPromptPreview()
                                        : null,
                                    aiProviderData: widget.enableLiveData
                                        ? const LiveAIProviderPreview()
                                        : null,
                                    aiSettingsData: widget.enableLiveData
                                        ? const LiveAISettingsPreview()
                                        : null,
                                    smartBillingData: widget.enableLiveData
                                        ? const LiveSmartBillingPreview()
                                        : null,
                                    analyticsData: widget.enableLiveData
                                        ? const LiveAnalyticsPreview()
                                        : null,
                                    calendarData: widget.enableLiveData
                                        ? const LiveCalendarPreview()
                                        : null,
                                    budgetEditorData: widget.enableLiveData
                                        ? const LiveBudgetEditorPreview()
                                        : null,
                                    budgetData: widget.enableLiveData
                                        ? const LiveBudgetPreview()
                                        : null,
                                    exchangeRateData: widget.enableLiveData
                                        ? const LiveExchangeRatePreview()
                                        : null,
                                    categoryMigrationData: widget.enableLiveData ? const LiveCategoryMigrationPreview() : null,
                                    attachmentLibraryData: widget.enableLiveData ? const LiveAttachmentLibraryPreview() : null,
                                    fileWorkflowData: widget.enableLiveData ? const LiveFileWorkflowPreview() : null,
                                    skinData: widget.enableLiveData ? const LiveSkinPreview() : null,
                                    noteHistoryData: widget.enableLiveData ? const LiveNoteHistoryPreview() : null,
                                    reminderData: widget.enableLiveData ? const LiveReminderPreview() : null,
                                    tagLibraryData: widget.enableLiveData ? const LiveTagLibraryPreview() : null,
                                    liveData: widget.enableLiveData ? const LiveBusinessPreview() : null))
                          ]))),
                  bottomNavigationBar: NavigationBar(
                      selectedIndex: tab,
                      onDestinationSelected: (v) => setState(() => tab = v),
                      destinations: const [
                        NavigationDestination(
                            icon: Icon(Icons.widgets_outlined), label: '基础组件'),
                        NavigationDestination(
                            icon: Icon(Icons.receipt_long_outlined),
                            label: '业务组件')
                      ]),
                )));
  }
}
