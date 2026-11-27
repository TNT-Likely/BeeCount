import 'dart:convert';

/// 云服务后端类型
enum CloudBackendType {
  local, // 本地存储(不同步)
  beecountCloud, // BeeCount Cloud（自建云服务）
  supabase, // Supabase (自建)
  webdav, // WebDAV (坚果云、Nextcloud、群晖等)
  icloud, // iCloud (iOS only)
  s3, // S3 协议（AWS S3、Cloudflare R2、MinIO等）
}

class CloudServiceConfig {
  final CloudBackendType type;
  final String name; // UI 展示名称
  final bool queueBeeCountChangesWhileLocal;

  bool get tracksBeeCountChanges =>
      (type == CloudBackendType.beecountCloud && valid) ||
      (type == CloudBackendType.local && queueBeeCountChangesWhileLocal);

  // BeeCount Cloud 配置
  final String? beecountCloudBaseUrl;
  final String? beecountCloudApiPrefix;
  final String? beecountCloudEmail; // 保存的账号（用于记住账号功能）
  final String? beecountCloudPassword; // 保存的密码（用于记住账号功能）

  // Supabase 配置
  final String? supabaseUrl;
  final String? supabaseAnonKey;
  final String? supabaseBucket; // Storage bucket 名称
  final String? supabaseEmail; // 保存的账号（用于记住账号功能）
  final String? supabasePassword; // 保存的密码（用于记住账号功能）

  // WebDAV 配置
  final String? webdavUrl;
  final String? webdavUsername;
  final String? webdavPassword;
  final String? webdavRemotePath;

  // S3 配置
  final String? s3Endpoint;
  final String? s3Region;
  final String? s3AccessKey;
  final String? s3SecretKey;
  final String? s3Bucket;
  final bool? s3UseSSL;
  final int? s3Port;

  const CloudServiceConfig({
    required this.type,
    required this.name,
    this.queueBeeCountChangesWhileLocal = false,
    // BeeCount Cloud
    this.beecountCloudBaseUrl,
    this.beecountCloudApiPrefix,
    this.beecountCloudEmail,
    this.beecountCloudPassword,
    // Supabase
    this.supabaseUrl,
    this.supabaseAnonKey,
    this.supabaseBucket,
    this.supabaseEmail,
    this.supabasePassword,
    // WebDAV
    this.webdavUrl,
    this.webdavUsername,
    this.webdavPassword,
    this.webdavRemotePath,
    // S3
    this.s3Endpoint,
    this.s3Region,
    this.s3AccessKey,
    this.s3SecretKey,
    this.s3Bucket,
    this.s3UseSSL,
    this.s3Port,
  });

  String get id => type.name; // 使用类型作为id

  bool get valid {
    switch (type) {
      case CloudBackendType.local:
        return true; // 本地存储始终有效
      case CloudBackendType.beecountCloud:
        return (beecountCloudBaseUrl?.isNotEmpty ?? false);
      case CloudBackendType.supabase:
        return (supabaseUrl?.isNotEmpty ?? false) &&
            (supabaseAnonKey?.isNotEmpty ?? false);
      case CloudBackendType.webdav:
        return (webdavUrl?.isNotEmpty ?? false) &&
            (webdavUsername?.isNotEmpty ?? false) &&
            (webdavPassword?.isNotEmpty ?? false);
      case CloudBackendType.icloud:
        return true; // iCloud 无需配置，始终有效
      case CloudBackendType.s3:
        return (s3Endpoint?.isNotEmpty ?? false) &&
            (s3AccessKey?.isNotEmpty ?? false) &&
            (s3SecretKey?.isNotEmpty ?? false) &&
            (s3Bucket?.isNotEmpty ?? false);
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'name': name,
        // BeeCount Cloud
        'beecountCloudBaseUrl': beecountCloudBaseUrl,
        'beecountCloudApiPrefix': beecountCloudApiPrefix,
        'beecountCloudEmail': beecountCloudEmail,
        'beecountCloudPassword': beecountCloudPassword,
        // Supabase
        'supabaseUrl': supabaseUrl,
        'supabaseAnonKey': supabaseAnonKey,
        'supabaseBucket': supabaseBucket,
        'supabaseEmail': supabaseEmail,
        'supabasePassword': supabasePassword,
        // WebDAV
        'webdavUrl': webdavUrl,
        'webdavUsername': webdavUsername,
        'webdavPassword': webdavPassword,
        'webdavRemotePath': webdavRemotePath,
        // S3
        's3Endpoint': s3Endpoint,
        's3Region': s3Region,
        's3AccessKey': s3AccessKey,
        's3SecretKey': s3SecretKey,
        's3Bucket': s3Bucket,
        's3UseSSL': s3UseSSL,
        's3Port': s3Port,
      };

  static CloudServiceConfig fromJson(Map<String, dynamic> j) {
    // 自动清理 S3 endpoint 中的协议前缀
    String? s3Endpoint = j['s3Endpoint'] as String?;
    if (s3Endpoint != null && s3Endpoint.isNotEmpty) {
      s3Endpoint = s3Endpoint.replaceFirst(RegExp(r'^https?://'), '');
    }

    return CloudServiceConfig(
      type: CloudBackendType.values
          .firstWhere((e) => e.name == j['type'] as String),
      name: j['name'] as String,
      // BeeCount Cloud
      beecountCloudBaseUrl: j['beecountCloudBaseUrl'] as String?,
      beecountCloudApiPrefix: j['beecountCloudApiPrefix'] as String?,
      beecountCloudEmail: j['beecountCloudEmail'] as String?,
      beecountCloudPassword: j['beecountCloudPassword'] as String?,
      // Supabase
      supabaseUrl: j['supabaseUrl'] as String?,
      supabaseAnonKey: j['supabaseAnonKey'] as String?,
      supabaseBucket: j['supabaseBucket'] as String?,
      supabaseEmail: j['supabaseEmail'] as String?,
      supabasePassword: j['supabasePassword'] as String?,
      // WebDAV
      webdavUrl: j['webdavUrl'] as String?,
      webdavUsername: j['webdavUsername'] as String?,
      webdavPassword: j['webdavPassword'] as String?,
      webdavRemotePath: j['webdavRemotePath'] as String?,
      // S3
      s3Endpoint: s3Endpoint,
      s3Region: j['s3Region'] as String?,
      s3AccessKey: j['s3AccessKey'] as String?,
      s3SecretKey: j['s3SecretKey'] as String?,
      s3Bucket: j['s3Bucket'] as String?,
      s3UseSSL: j['s3UseSSL'] as bool?,
      s3Port: j['s3Port'] as int?,
    );
  }

  // 本地存储配置(默认)
  static CloudServiceConfig localStorage({bool queueBeeCountChanges = false}) => CloudServiceConfig(
        type: CloudBackendType.local,
        name: '__LOCAL_STORAGE__',
        queueBeeCountChangesWhileLocal: queueBeeCountChanges,
      );

  String obfuscatedUrl() {
    switch (type) {
      case CloudBackendType.local:
        return '__LOCAL_DEVICE__';
      case CloudBackendType.beecountCloud:
        if (beecountCloudBaseUrl == null || beecountCloudBaseUrl!.isEmpty) {
          return '__NOT_CONFIGURED__';
        }
        try {
          final uri = Uri.parse(beecountCloudBaseUrl!);
          if (uri.host.isEmpty) return beecountCloudBaseUrl!;
          return uri.host;
        } catch (_) {
          return beecountCloudBaseUrl!;
        }
      case CloudBackendType.supabase:
        if (supabaseUrl == null || supabaseUrl!.isEmpty) {
          return '__NOT_CONFIGURED__'; // 特殊标记，在UI层处理本地化
        }
        // 仅显示域名部分（隐藏具体 path / 项目 id）
        try {
          final uri = Uri.parse(supabaseUrl!);
          if (uri.host.isEmpty) return supabaseUrl!; // 如果没有host，返回原始URL
          return uri.host; // 不展示 scheme 与后缀
        } catch (_) {
          return supabaseUrl!; // 解析失败，返回原始URL
        }

      case CloudBackendType.webdav:
        if (webdavUrl == null || webdavUrl!.isEmpty) {
          return '__NOT_CONFIGURED__';
        }
        // 显示WebDAV服务器地址的域名部分
        try {
          final uri = Uri.parse(webdavUrl!);
          if (uri.host.isEmpty) return webdavUrl!; // 如果没有host，返回原始URL
          return uri.host;
        } catch (_) {
          return webdavUrl!; // 解析失败，返回原始URL
        }

      case CloudBackendType.icloud:
        return 'iCloud Drive';

      case CloudBackendType.s3:
        if (s3Endpoint == null || s3Endpoint!.isEmpty) {
          return '__NOT_CONFIGURED__';
        }
        // 显示 endpoint / bucket
        final bucket = s3Bucket ?? '';
        return bucket.isEmpty ? s3Endpoint! : '$s3Endpoint / $bucket';
    }
  }
}

String encodeCloudConfig(CloudServiceConfig c) => jsonEncode(c.toJson());
CloudServiceConfig decodeCloudConfig(String raw) =>
    CloudServiceConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
