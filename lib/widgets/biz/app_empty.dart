import 'package:flutter/material.dart';

class AppEmpty extends StatelessWidget {
  final String text;
  const AppEmpty({super.key, this.text = '暂无数据'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
