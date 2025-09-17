import 'package:flutter/material.dart';
import '../widgets/ui/ui.dart';

class UiDemoPage extends StatefulWidget {
  const UiDemoPage({super.key});

  @override
  State<UiDemoPage> createState() => _UiDemoPageState();
}

class _UiDemoPageState extends State<UiDemoPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UI 组件演示'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 对话框演示
          _SectionCard(
            title: '对话框组件',
            children: [
              ElevatedButton(
                onPressed: () async {
                  await AppDialog.info(
                    context,
                    title: '信息提示',
                    message: '这是一个信息提示对话框示例',
                  );
                },
                child: const Text('显示信息对话框'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final result = await AppDialog.confirm(
                    context,
                    title: '确认对话框',
                    message: '这是一个确认对话框示例，您确定要继续吗？',
                  );
                  if (result == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('用户点击了确认')),
                    );
                  }
                },
                child: const Text('显示确认对话框'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Toast 演示
          _SectionCard(
            title: 'Toast 组件',
            children: [
              ElevatedButton(
                onPressed: () {
                  showToast(context, '操作成功！');
                },
                child: const Text('显示成功 Toast'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  showToast(context, '操作失败！');
                },
                child: const Text('显示错误 Toast'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  showToast(context, '这是一条信息提示');
                },
                child: const Text('显示信息 Toast'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 日期选择器演示
          _SectionCard(
            title: '日期选择器',
            children: [
              ElevatedButton(
                onPressed: () async {
                  final date = await showWheelDatePicker(
                    context,
                    initial: DateTime.now(),
                  );
                  if (date != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('选择的日期: ${date.toString().split(' ')[0]}')),
                    );
                  }
                },
                child: const Text('显示日期选择器'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 时间选择器演示
          _SectionCard(
            title: '时间选择器',
            children: [
              ElevatedButton(
                onPressed: () async {
                  final time = await showWheelTimePicker(
                    context,
                    initial: TimeOfDay.now(),
                  );
                  if (time != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('选择的时间: ${time.format(context)}')),
                    );
                  }
                },
                child: const Text('显示时间选择器'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 下拉搜索组件演示
          _SectionCard(
            title: '下拉搜索组件',
            children: [
              SearchableDropdown<String>(
                items: const ['选项1', '选项2', '选项3', '苹果', '香蕉', '橙子'],
                itemBuilder: (item) => Text(item),
                filter: (item, query) => item.toLowerCase().contains(query.toLowerCase()),
                labelExtractor: (item) => item,
                onChanged: (value) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('选择了: $value')),
                    );
                  }
                },
                hintText: '请选择或搜索选项',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}