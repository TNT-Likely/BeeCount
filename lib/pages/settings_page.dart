import 'package:flutter/material.dart';
import 'import_page.dart';
import 'personalize_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../widgets/primary_header.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ListView(
        children: [
          const PrimaryHeader(title: '设置', showBack: true),
          ListTile(
            leading: const Icon(Icons.today_outlined),
            title: const Text('跳转到本月'),
            onTap: () {
              final now = DateTime.now();
              ref.read(selectedMonthProvider.notifier).state =
                  DateTime(now.year, now.month, 1);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('导入账单（CSV 文件/粘贴）'),
            subtitle: const Text('日期,类型,金额,备注'),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportPage()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.brush_outlined),
            title: const Text('个性化'),
            subtitle: const Text('头部换装（仅主色调样式）'),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PersonalizePage()),
              );
            },
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于'),
            subtitle: Text('版本与开源协议'),
          ),
        ],
      ),
    );
  }
}
