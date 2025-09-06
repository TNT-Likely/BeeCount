import 'package:flutter/material.dart';
import '../widgets/primary_header.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: const [
          PrimaryHeader(title: '图表'),
          Expanded(child: Center(child: Text('图表分析（饼图/柱状图）'))),
        ],
      ),
    );
  }
}
