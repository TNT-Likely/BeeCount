import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import 'logger_service.dart';

/// Opt-in export projection. Unknown or old free-form values carry no
/// releasable text; only values from the dictionaries below reach the file.
LogEntry redactLogEntry(LogEntry entry) {
  final tag = _modules.lookup(entry.tag) ?? 'Other';
  final frames = _trustedStack(entry.stackTrace);
  return LogEntry(
    timestamp: entry.timestamp,
    level: entry.level,
    platform: entry.platform,
    tag: tag,
    message: _event(tag, entry.message),
    error: _errorKind(entry.error),
    stackTrace:
        frames.isEmpty ? null : StackTrace.fromString(frames.join('\n')),
  );
}

const _modules = <String>{
  'App',
  'Main',
  'AppStart',
  'MainActivity',
  'AppDelegate',
  'AppLink',
  'auth',
  'AppLock',
  'DB',
  'db',
  'DBMigration',
  'LocalRepository',
  'CloudSync',
  'SyncEngine',
  'SyncProvider',
  'CloudService',
  'iCloud',
  'profile_sync',
  'avatar_sync',
  'ChangeTracker',
  'SyncDiff',
  'AIFactory',
  'AiExtraction',
  'JsonResponseParser',
  'AIChat',
  'AgentCore',
  'AIConfig',
  'AutoBilling',
  'VoiceBilling',
  'ImageShare',
  'Widget',
  'WidgetManager',
  'ConfigImport',
  'ConfigExport',
  'TxImport',
  'AttachmentService',
  'AttachmentExportImport',
  'AllAccountsTotalStats',
  'UpdateService',
  'UpdateDownloader',
  'UpdateInstaller',
  'AboutPage',
};

// Only app-owned message prefixes have a public event name. Never copy a
// suffix, which can contain a complete bill, AI response or remote endpoint.
const _eventNames = <String, Map<String, String>>{
  'App': {'应用启动，日志系统已初始化': 'app.started'},
  'auth': {
    '开始登录': 'login.started',
    '登录成功': 'login.completed',
    '登录失败': 'login.failed',
  },
  'SyncEngine': {
    '开始同步': 'sync.started',
    '同步完成': 'sync.completed',
    '同步失败': 'sync.failed',
    '附件上传失败': 'attachment.upload.failed',
    '附件下载失败': 'attachment.download.failed',
  },
  'CloudSync': {
    '下载远程账本失败': 'ledger.download.failed',
    '删除远程账本失败': 'ledger.delete.failed',
    '恢复所有远程账本失败': 'ledger.restore.failed',
  },
  'AiExtraction': {
    '文本账单提取': 'ai.text.extract',
    '图片账单提取': 'ai.image.extract',
    '语音账单提取': 'ai.voice.extract',
    '识别结果:': 'ai.voice.transcribed',
  },
  'JsonResponseParser': {
    '原始响应:': 'ai.response.received',
    '账单提取成功': 'ai.response.parsed',
    '响应中没有找到 JSON': 'ai.response.invalid',
    '单对象 JSON 解析失败': 'ai.response.invalid',
  },
  'AutoBilling': {
    '开始处理截图': 'screenshot.started',
    '截图文件等待超时': 'screenshot.timeout',
    '自动记账成功': 'billing.completed',
    '处理截图失败': 'screenshot.failed',
  },
};

final _httpStatus = RegExp(r'^HTTP错误: ([1-5][0-9]{2}), 响应:');

String _event(String tag, String message) {
  if (tag == 'AIFactory') {
    final status = _httpStatus.firstMatch(message);
    if (status != null) return 'HTTP ${status[1]}';
  }
  final names = _eventNames[tag];
  if (names != null) {
    for (final name in names.entries) {
      if (message.startsWith(name.key)) return name.value;
    }
  }
  return '[redacted]';
}

const _knownErrorTypes = <String>{
  'ArgumentError',
  'StateError',
  'FormatException',
  'TimeoutException',
  'SocketException',
  'HttpException',
  'HandshakeException',
  'FileSystemException',
  'PlatformException',
  'DioException',
  'CloudAuthException',
  'AIException',
};
final _errorPrefix = RegExp(r'^([A-Za-z]{1,32})(?=[:(\s]|$)');

String? _errorKind(Object? error) {
  if (error == null) return null;
  if (error is DioException) {
    final kind = 'DioException.${error.type.name}';
    final status = error.response?.statusCode;
    return status != null && status >= 100 && status <= 599
        ? '$kind (HTTP $status)'
        : kind;
  }
  if (error is FormatException) return 'FormatException';
  if (error is TimeoutException) return 'TimeoutException';
  if (error is SocketException) return 'SocketException';
  if (error is HttpException) return 'HttpException';
  if (error is HandshakeException) return 'HandshakeException';
  if (error is FileSystemException) return 'FileSystemException';
  if (error is PlatformException) return 'PlatformException';
  if (error is StateError) return 'StateError';
  if (error is ArgumentError) return 'ArgumentError';

  // Restored log entries store exceptions as text, losing the original type.
  if (error is String) {
    if (error.startsWith('Bad state:')) return 'StateError';
    final type = _errorPrefix.firstMatch(error)?.group(1);
    return _knownErrorTypes.lookup(type) ?? 'Error';
  }
  return 'Error';
}

const _trustedSymbols = <String, Set<String>>{
  'cloud/sync/sync_engine.dart': {
    'SyncEngine.sync',
    'SyncEngine.pull',
    'SyncEngine.push',
    'SyncEngine._doPull',
    'SyncEngine._doPush',
    'SyncEngine._runPullLoop',
    'SyncEngine.runFullPull',
  },
  'cloud/transactions_sync_manager.dart': {
    'TransactionsSyncManager.downloadRemoteLedger',
    'TransactionsSyncManager.uploadCurrentLedger',
    'TransactionsSyncManager.downloadAndPreview',
  },
  'ai/core/ai_extraction_engine.dart': {
    'DefaultAiExtractionEngine.extractFromText',
    'DefaultAiExtractionEngine.extractFromImage',
    'DefaultAiExtractionEngine.extractFromAudio',
    'DefaultAiExtractionEngine.speechToText',
  },
  'ai/core/json_response_parser.dart': {'JsonResponseParser.parse'},
  'widget/widget_manager.dart': {'WidgetManager._renderView'},
  'services/automation/auto_billing_service.dart': {
    'AutoBillingService.processScreenshot'
  },
  'pages/cloud/configuration/bindings/cloud_login_controls.dart': {
    '_CloudLoginControlsState._login'
  },
};
final _packageFrame = RegExp(
  r'^#[0-9]+[ \t]+([\w.]+)(?:\.<anonymous closure>)*[ \t]+'
  r'\(package:beecount/([\w/]+\.dart):[0-9]+(?::[0-9]+)?\)\r?$',
  multiLine: true,
);

List<String> _trustedStack(StackTrace? stack) {
  if (stack == null) return const [];
  final frames = <String>[];
  for (final match in _packageFrame.allMatches(stack.toString())) {
    final symbol = _trustedSymbols[match[2]]?.lookup(match[1]);
    if (symbol == null) continue;
    frames.add(symbol);
    if (frames.length == 8) break;
  }
  return frames;
}
