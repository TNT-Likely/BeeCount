import 'dart:convert';

/// 仅支持一种后端：Supabase（可扩展保留枚举）
enum CloudBackendType { supabase }

class CloudServiceConfig {
  final String id; // 'builtin' | 'custom'
  final CloudBackendType type;
  final String name; // UI 展示名称
  final String? supabaseUrl;
  final String? supabaseAnonKey;
  final bool builtin; // 是否内置（不可编辑 / 隐藏真实值）

  const CloudServiceConfig({
    required this.id,
    required this.type,
    required this.name,
    this.supabaseUrl,
    this.supabaseAnonKey,
    this.builtin = false,
  });

  bool get valid =>
      type == CloudBackendType.supabase &&
      (supabaseUrl?.isNotEmpty ?? false) &&
      (supabaseAnonKey?.isNotEmpty ?? false);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'supabaseUrl': supabaseUrl,
        'supabaseAnonKey': supabaseAnonKey,
        'builtin': builtin,
      };

  static CloudServiceConfig fromJson(Map<String, dynamic> j) =>
      CloudServiceConfig(
        id: j['id'] as String,
        type: CloudBackendType.values
            .firstWhere((e) => e.name == j['type'] as String),
        name: j['name'] as String,
        supabaseUrl: j['supabaseUrl'] as String?,
        supabaseAnonKey: j['supabaseAnonKey'] as String?,
        builtin: j['builtin'] == true,
      );

  static CloudServiceConfig builtinDefault({String? url, String? key}) =>
      CloudServiceConfig(
        id: 'builtin',
        type: CloudBackendType.supabase,
        name: '默认云服务',
        supabaseUrl: url?.isNotEmpty == true ? url : null,
        supabaseAnonKey: key?.isNotEmpty == true ? key : null,
        builtin: true,
      );

  String obfuscatedUrl() {
    if (supabaseUrl == null || supabaseUrl!.isEmpty) return '未配置';
    // 仅显示域名部分（隐藏具体 path / 项目 id）
    try {
      final uri = Uri.parse(supabaseUrl!);
      return uri.host; // 不展示 scheme 与后缀
    } catch (_) {
      return '***';
    }
  }
}

String encodeCloudConfig(CloudServiceConfig c) => jsonEncode(c.toJson());
CloudServiceConfig decodeCloudConfig(String raw) =>
    CloudServiceConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
