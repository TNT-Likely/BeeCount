import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:beecount/services/automation/auto_billing_service.dart';

class XposedService {
  static final XposedService _instance = XposedService._internal();
  factory XposedService() => _instance;
  XposedService._internal();

  static const platform = MethodChannel('com.beecount.api/broadcast');
  AutoBillingService? _autoBillingService;

  void init(WidgetRef ref, BuildContext context) {
    print("🚀 自动记账服务启动 (管道模式)...");

    platform.setMethodCallHandler((call) async {
      if (call.method == 'addTransaction') {
        print("📞 [XposedService] 收到 Native 调用"); 
        
        try {
          // 🟢 补全：初始化发动机 (之前就是少了这一段)
          if (_autoBillingService == null) {
            print("🛠️ [XposedService] 正在初始化 AutoBillingService...");
            // 通过 context 获取全局的 ProviderContainer
            _autoBillingService = AutoBillingService(ProviderScope.containerOf(context));
          }

          final Map args = call.arguments as Map;
          
          final String amountStr = args['amount']?.toString() ?? '0';
          final String note = args['remark']?.toString() ?? '';
          final String category = args['category']?.toString() ?? '';
          final String type = args['type']?.toString() ?? 'expense'; 
          final String account = args['account']?.toString() ?? '';
          
          String finalNote = note.isNotEmpty ? note : category;

          // 构造暗号
          final String commandText = "XPOSED:$amountStr|$finalNote|$category|$type|$account";
          print("📥 [API匹配] 协议转发: $commandText");

          // 🟢 补全：调用逻辑
          if (_autoBillingService != null) {
            print("🚀 [XposedService] 指令已分发至 AutoBillingService");
            await _autoBillingService!.processText(commandText, showNotification: true);
          } else {
            print("❌ [XposedService] 初始化失败，无法处理指令");
          }
          
          return "Success";

        } catch (e) {
          print("❌ [XposedService] 异常: $e");
          return "Error: $e";
        }
      }
      return null;
    });
  }
}