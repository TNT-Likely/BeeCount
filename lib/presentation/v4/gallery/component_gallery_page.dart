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
                        PopupMenuButton<Color>(
                            tooltip: '切换主题色',
                            onSelected: (v) => setState(() => accent = v),
                            itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: Color(0xfffacb16),
                                      child: Text('蜜蜂黄')),
                                  PopupMenuItem(
                                      value: Color(0xff49a396),
                                      child: Text('薄荷绿')),
                                  PopupMenuItem(
                                      value: Color(0xff7771db),
                                      child: Text('鸢尾紫'))
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
                                enabled: tab == 0,
                                child: const FoundationAcceptancePage()),
                            TickerMode(
                                enabled: tab == 1,
                                child: BusinessAcceptancePage(
                                    budgetData: widget.enableLiveData
                                        ? const LiveBudgetPreview()
                                        : null,
                                    exchangeRateData: widget.enableLiveData
                                        ? const LiveExchangeRatePreview()
                                        : null,
                                    categoryMigrationData: widget.enableLiveData
                                        ? const LiveCategoryMigrationPreview()
                                        : null,
                                    attachmentLibraryData: widget.enableLiveData
                                        ? const LiveAttachmentLibraryPreview()
                                        : null,
                                    fileWorkflowData: widget.enableLiveData
                                        ? const LiveFileWorkflowPreview()
                                        : null,
                                    skinData: widget.enableLiveData
                                        ? const LiveSkinPreview()
                                        : null,
                                    noteHistoryData: widget.enableLiveData
                                        ? const LiveNoteHistoryPreview()
                                        : null,
                                    reminderData: widget.enableLiveData
                                        ? const LiveReminderPreview()
                                        : null,
                                    tagLibraryData: widget.enableLiveData
                                        ? const LiveTagLibraryPreview()
                                        : null,
                                    liveData: widget.enableLiveData
                                        ? const LiveBusinessPreview()
                                        : null))
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
