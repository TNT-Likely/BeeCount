import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/auth_service.dart';
import '../core/cloud_provider.dart';
import '../core/exceptions.dart';
import '../core/storage_service.dart';
import '../utils/path_helper.dart';

// ============================================================================
// 2FA(TOTP)— 见 BeeCount 主仓 .docs/2fa-design.md
// ============================================================================
// 设计要点:
// - 启用 / 管理 UI 只在 Web 端;App 仅承担"登录时若 server 要 2FA → 弹出输码视图"
// - 两处登录入口(cloud_service_page 配置确认 / beecount_cloud_sync_page 重新登录)
//   不感知 2FA — 只 await `signInWithEmail()`,2FA 流程被封装在 service 内部
// - service 通过 `BeeCountCloudProvider.globalTwoFactorHandler` 拿到回调,
//   handler 由 App 在启动时注册(典型实现:用全局 navigator key push 一个
//   `Login2FAChallengeView`,等用户输完码后 resolve)

/// 当 server 返回 requires_2fa=true 时,通过 [TwoFactorChallengeHandler] 传给 App。
///
/// `verify` 由 service 注入:UI 在用户输完码点验证后调它,
/// 返回 null = 验证通过(UI 应关闭对话框并让 handler 返回 true),
/// 返回非 null 字符串 = 错误信息(UI 就地展示,让用户重试)。
///
/// 这样 view 留在原地,失败可重试,不再"输错就跳走没提示"。
class TwoFactorChallengeRequest {
  final String challengeToken;
  final List<String> availableMethods; // ['totp', 'recovery_code']
  final String email;
  final Future<String?> Function(String method, String code) verify;

  const TwoFactorChallengeRequest({
    required this.challengeToken,
    required this.availableMethods,
    required this.email,
    required this.verify,
  });
}

/// 处理 2FA challenge 的回调。返回 true = 验证已通过(view 内调 verify 返回 null),
/// false = 用户取消 / 关闭对话框。
typedef TwoFactorChallengeHandler = Future<bool> Function(
  TwoFactorChallengeRequest request,
);

/// `/auth/2fa/status` 响应。
class TwoFactorStatus {
  final bool enabled;
  final DateTime? enabledAt;

  const TwoFactorStatus({required this.enabled, this.enabledAt});
}

/// 用户在 2FA 输码视图取消了流程 — 把它当成普通登录失败抛出去。
class TwoFactorCancelledException implements Exception {
  final String message;
  const TwoFactorCancelledException([this.message = '2FA verification cancelled']);
  @override
  String toString() => 'TwoFactorCancelledException: $message';
}

class BeeCountCloudProvider implements CloudProvider {
  /// 在 App 启动时设置一次。auth service 处理 signInWithEmail 时,server
  /// 若返回 requires_2fa=true,会调这个 handler 让 App 弹输码 UI。
  /// 不设置 = 老 App / 服务端未启 2FA 行为不变;若 server 要求 2FA 而 App
  /// 没注册 handler,signInWithEmail 会抛 [CloudAuthException]。
  static TwoFactorChallengeHandler? globalTwoFactorHandler;

  BeeCountCloudAuthService? _auth;
  BeeCountCloudStorageService? _storage;
  BeeCountCloudRealtimeClient? _realtime;

  @override
  String get providerId => 'beecount_cloud';

  @override
  String get providerName => 'BeeCount Cloud';

  /// 拼接绝对 URL 用 — 头像 / 附件下载等场景。null = 未初始化。
  String? get baseUrl => _auth?.baseUrl;
  String? get apiPrefix => _auth?.apiPrefix;

  @override
  CloudAuthService get auth {
    final auth = _auth;
    if (auth == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud provider is not initialized.');
    }
    return auth;
  }

  @override
  CloudStorageService get storage {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud provider is not initialized.');
    }
    return storage;
  }

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    if (!validateConfig(config)) {
      throw CloudConfigurationException(
          'Invalid BeeCount Cloud config. Required: baseUrl');
    }

    final rawBaseUrl = (config['baseUrl'] as String).trim();
    final rawApiPrefix = (config['apiPrefix'] as String?)?.trim();
    final baseUrl = rawBaseUrl.replaceFirst(RegExp(r'/$'), '');
    final apiPrefix = _normalizeApiPrefix(rawApiPrefix ?? '/api/v1');

    final authService = BeeCountCloudAuthService(
      baseUrl: baseUrl,
      apiPrefix: apiPrefix,
      twoFactorHandler: BeeCountCloudProvider.globalTwoFactorHandler,
    );
    await authService.initialize();

    _auth = authService;
    final storage = BeeCountCloudStorageService(
      baseUrl: baseUrl,
      apiPrefix: apiPrefix,
      auth: authService,
    );
    _storage = storage;
    _realtime = BeeCountCloudRealtimeClient(
      baseUrl: baseUrl,
      auth: authService,
    );
  }

  @override
  bool validateConfig(Map<String, dynamic> config) {
    final baseUrl = config['baseUrl'];
    if (baseUrl is! String || baseUrl.trim().isEmpty) {
      return false;
    }
    final apiPrefix = config['apiPrefix'];
    if (apiPrefix != null && apiPrefix is! String) {
      return false;
    }
    return true;
  }

  @override
  Future<void> dispose() async {
    await _realtime?.stop();
    _realtime?.dispose();
    _realtime = null;
    _storage?.dispose();
    _storage = null;
    _auth?.dispose();
    _auth = null;
  }

  Stream<BeeCountCloudRealtimeEvent> get realtimeEvents {
    final realtime = _realtime;
    if (realtime == null) {
      return const Stream.empty();
    }
    return realtime.events;
  }

  Future<void> startRealtime() async {
    final realtime = _realtime;
    if (realtime == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud realtime is not initialized.');
    }
    await realtime.start();
  }

  Future<void> stopRealtime() async {
    await _realtime?.stop();
  }

  Future<BeeCountCloudProfile> getMyProfile() async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.getMyProfile();
  }

  /// 转发到 BeeCountCloudAuthService.getTwoFactorStatus,云同步页用它展示状态行。
  Future<TwoFactorStatus> getTwoFactorStatus() async {
    final auth = _auth;
    if (auth == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud auth is not initialized.');
    }
    return auth.getTwoFactorStatus();
  }

  Future<BeeCountCloudProfile> updateMyProfileDisplayName({
    required String displayName,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.updateMyProfileDisplayName(displayName: displayName);
  }

  Future<BeeCountCloudAvatarUploadResult> uploadMyAvatar({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.uploadMyAvatar(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  /// 更新收支颜色方案偏好，对齐 mobile `incomeExpenseColorSchemeProvider`。
  /// 把 bool 推给 `/profile/me` PATCH，server 端 broadcast 后 web 也会实时切换。
  Future<BeeCountCloudProfile> updateMyProfileIncomeColorScheme({
    required bool incomeIsRed,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.updateMyProfileIncomeColorScheme(
      incomeIsRed: incomeIsRed,
    );
  }

  /// 更新主题色。hex 形如 `#F59E0B`。单向 mobile → server → web，web 本地改
  /// 色不回推；这个 API 只给 mobile 用。
  Future<BeeCountCloudProfile> updateMyProfileThemeColor({
    required String hex,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.updateMyProfileThemeColor(hex: hex);
  }

  /// 更新外观类设置(JSON 形式),当前包括 header_decoration_style /
  /// compact_amount / show_transaction_time。字体缩放不进来。
  Future<BeeCountCloudProfile> updateMyProfileAppearance({
    required Map<String, dynamic> appearance,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.updateMyProfileAppearance(appearance: appearance);
  }

  /// 更新 AI 配置(providers / binding / custom_prompt / strategy 等)。
  /// 注意:API key 属于敏感字段,这条 API 只在用户自己的 session 走。
  Future<BeeCountCloudProfile> updateMyProfileAiConfig({
    required Map<String, dynamic> aiConfig,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.updateMyProfileAiConfig(aiConfig: aiConfig);
  }

  /// 下载自己的头像字节流。服务端路径是 `/profile/avatar/{user_id}?v=<v>`，
  /// 跟 `/attachments/{fileId}` 不是一回事 —— 头像存储独立于 attachment，
  /// 之前 sync_engine 用 downloadAttachment + 正则解析 `attachments/(.+)`
  /// 从 avatar_url 抠 fileId 的路径永远抠不出来，所以初次同步从来没真的
  /// 下载过头像。这里给一个专用方法。
  Future<Uint8List> downloadMyAvatar({
    required String userId,
    int? version,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.downloadMyAvatar(userId: userId, version: version);
  }

  Future<BeeCountCloudPullResult> pullChanges({
    int? since,
    int limit = 1000,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.pullChanges(since: since, limit: limit);
  }

  /// 推送增量变更（个体实体级别，非 ledger_snapshot 包装）
  Future<void> pushChanges({
    required List<Map<String, dynamic>> changes,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.pushEntityChanges(changes: changes);
  }

  Future<Map<String, BeeCountCloudAttachmentExistsItem>> attachmentBatchExists({
    required String ledgerId,
    required List<String> sha256List,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.attachmentBatchExists(
      ledgerId: ledgerId,
      sha256List: sha256List,
    );
  }

  Future<BeeCountCloudAttachmentUploadResult> uploadAttachment({
    required String ledgerId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.uploadAttachment(
      ledgerId: ledgerId,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  /// 上传分类自定义图标 — user-global,不绑 ledger。
  Future<BeeCountCloudAttachmentUploadResult> uploadCategoryIcon({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.uploadCategoryIcon(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  Future<Uint8List> downloadAttachment({required String fileId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.downloadAttachment(fileId: fileId);
  }

  Future<List<BeeCountCloudDevice>> listDevices({
    String view = 'deduped',
    int activeWithinDays = 30,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.listDevices(
      view: view,
      activeWithinDays: activeWithinDays,
    );
  }

  Future<void> revokeDevice({required String deviceId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.revokeDevice(deviceId: deviceId);
  }

  Future<List<BeeCountCloudReadLedger>> readLedgers() async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.readLedgers();
  }

  Future<BeeCountCloudReadLedgerDetail> readLedgerDetail({
    required String ledgerId,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.readLedgerDetail(ledgerId: ledgerId);
  }

  Future<BeeCountCloudLedgerStats> readLedgerStats({
    required String ledgerId,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.readLedgerStats(ledgerId: ledgerId);
  }

  /// 拉 server 版本号(公开端点,不需要 token)。用在设置页展示
  /// "BeeCount Cloud vX.Y.Z"。失败抛,调用方自己 swallow。
  Future<BeeCountCloudServerVersion> fetchServerVersion() async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.fetchServerVersion();
  }

  // ===========================================================================
  // 共享账本(Sprint 2.4):invites + members + shared-resources
  // ===========================================================================

  Future<BeeCountCloudInvite> createInvite({
    required String ledgerId,
    String role = 'editor',
    int expiresInHours = 24,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.createInvite(
      ledgerId: ledgerId, role: role, expiresInHours: expiresInHours,
    );
  }

  Future<List<BeeCountCloudInvite>> listInvites({required String ledgerId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('BeeCount Cloud storage is not initialized.');
    }
    return storage.listInvites(ledgerId: ledgerId);
  }

  Future<void> revokeInvite({required String ledgerId, required String code}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('BeeCount Cloud storage is not initialized.');
    }
    return storage.revokeInvite(ledgerId: ledgerId, code: code);
  }

  Future<BeeCountCloudInvitePreview> previewInvite({required String code}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('BeeCount Cloud storage is not initialized.');
    }
    return storage.previewInvite(code: code);
  }

  Future<BeeCountCloudInviteAcceptResult> acceptInvite({required String code}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('BeeCount Cloud storage is not initialized.');
    }
    return storage.acceptInvite(code: code);
  }

  Future<List<BeeCountCloudLedgerMember>> listMembers({required String ledgerId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('BeeCount Cloud storage is not initialized.');
    }
    return storage.listMembers(ledgerId: ledgerId);
  }

  Future<BeeCountCloudLedgerMember> updateMemberRole({
    required String ledgerId,
    required String userId,
    required String role,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('BeeCount Cloud storage is not initialized.');
    }
    return storage.updateMemberRole(ledgerId: ledgerId, userId: userId, role: role);
  }

  Future<void> removeMember({required String ledgerId, required String userId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('BeeCount Cloud storage is not initialized.');
    }
    return storage.removeMember(ledgerId: ledgerId, userId: userId);
  }

  Future<BeeCountCloudSharedResources> fetchSharedResources({required String ledgerId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('BeeCount Cloud storage is not initialized.');
    }
    return storage.fetchSharedResources(ledgerId: ledgerId);
  }

  Future<BeeCountCloudMemberStats> fetchMemberStats({
    required String ledgerId,
    String scope = 'month',
    String? period,
    int? tzOffsetMinutes,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('BeeCount Cloud storage is not initialized.');
    }
    return storage.fetchMemberStats(
      ledgerId: ledgerId,
      scope: scope,
      period: period,
      tzOffsetMinutes: tzOffsetMinutes,
    );
  }

  Future<List<BeeCountCloudReadTransaction>> readTransactions({
    required String ledgerId,
    String? txType,
    String? query,
    DateTime? startAt,
    DateTime? endAt,
    int limit = 200,
    int offset = 0,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.readTransactions(
      ledgerId: ledgerId,
      txType: txType,
      query: query,
      startAt: startAt,
      endAt: endAt,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<BeeCountCloudReadAccount>> readAccounts({
    required String ledgerId,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.readAccounts(ledgerId: ledgerId);
  }

  Future<List<BeeCountCloudReadCategory>> readCategories({
    required String ledgerId,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.readCategories(ledgerId: ledgerId);
  }

  Future<List<BeeCountCloudReadTag>> readTags({
    required String ledgerId,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.readTags(ledgerId: ledgerId);
  }

  Future<BeeCountCloudWriteCommitMeta> writeCreateLedger({
    String? ledgerId,
    required String ledgerName,
    String currency = 'CNY',
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeCreateLedger(
      ledgerId: ledgerId,
      ledgerName: ledgerName,
      currency: currency,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeLedgerMeta({
    required String ledgerId,
    required int baseChangeId,
    String? ledgerName,
    String? currency,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeLedgerMeta(
      ledgerId: ledgerId,
      baseChangeId: baseChangeId,
      ledgerName: ledgerName,
      currency: currency,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeCreateTransaction({
    required String ledgerId,
    required int baseChangeId,
    required String txType,
    required double amount,
    required DateTime happenedAt,
    String? note,
    String? categoryName,
    String? categoryKind,
    String? accountName,
    String? fromAccountName,
    String? toAccountName,
    String? categoryId,
    String? accountId,
    String? fromAccountId,
    String? toAccountId,
    Object? tags,
    List<String>? tagIds,
    List<Map<String, dynamic>>? attachments,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeCreateTransaction(
      ledgerId: ledgerId,
      baseChangeId: baseChangeId,
      txType: txType,
      amount: amount,
      happenedAt: happenedAt,
      note: note,
      categoryName: categoryName,
      categoryKind: categoryKind,
      accountName: accountName,
      fromAccountName: fromAccountName,
      toAccountName: toAccountName,
      categoryId: categoryId,
      accountId: accountId,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      tags: tags,
      tagIds: tagIds,
      attachments: attachments,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeUpdateTransaction({
    required String ledgerId,
    required String txId,
    required int baseChangeId,
    String? txType,
    double? amount,
    DateTime? happenedAt,
    String? note,
    String? categoryName,
    String? categoryKind,
    String? accountName,
    String? fromAccountName,
    String? toAccountName,
    String? categoryId,
    String? accountId,
    String? fromAccountId,
    String? toAccountId,
    Object? tags,
    List<String>? tagIds,
    List<Map<String, dynamic>>? attachments,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeUpdateTransaction(
      ledgerId: ledgerId,
      txId: txId,
      baseChangeId: baseChangeId,
      txType: txType,
      amount: amount,
      happenedAt: happenedAt,
      note: note,
      categoryName: categoryName,
      categoryKind: categoryKind,
      accountName: accountName,
      fromAccountName: fromAccountName,
      toAccountName: toAccountName,
      categoryId: categoryId,
      accountId: accountId,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      tags: tags,
      tagIds: tagIds,
      attachments: attachments,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeDeleteTransaction({
    required String ledgerId,
    required String txId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeDeleteTransaction(
      ledgerId: ledgerId,
      txId: txId,
      baseChangeId: baseChangeId,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeCreateAccount({
    required String ledgerId,
    required int baseChangeId,
    required String name,
    String? accountType,
    String? currency,
    double? initialBalance,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeCreateAccount(
      ledgerId: ledgerId,
      baseChangeId: baseChangeId,
      name: name,
      accountType: accountType,
      currency: currency,
      initialBalance: initialBalance,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeUpdateAccount({
    required String ledgerId,
    required String accountId,
    required int baseChangeId,
    String? name,
    String? accountType,
    String? currency,
    double? initialBalance,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeUpdateAccount(
      ledgerId: ledgerId,
      accountId: accountId,
      baseChangeId: baseChangeId,
      name: name,
      accountType: accountType,
      currency: currency,
      initialBalance: initialBalance,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeDeleteAccount({
    required String ledgerId,
    required String accountId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeDeleteAccount(
      ledgerId: ledgerId,
      accountId: accountId,
      baseChangeId: baseChangeId,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeCreateCategory({
    required String ledgerId,
    required int baseChangeId,
    required String name,
    required String kind,
    int? level,
    int? sortOrder,
    String? icon,
    String? iconType,
    String? customIconPath,
    String? iconCloudFileId,
    String? iconCloudSha256,
    String? parentName,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeCreateCategory(
      ledgerId: ledgerId,
      baseChangeId: baseChangeId,
      name: name,
      kind: kind,
      level: level,
      sortOrder: sortOrder,
      icon: icon,
      iconType: iconType,
      customIconPath: customIconPath,
      iconCloudFileId: iconCloudFileId,
      iconCloudSha256: iconCloudSha256,
      parentName: parentName,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeUpdateCategory({
    required String ledgerId,
    required String categoryId,
    required int baseChangeId,
    String? name,
    String? kind,
    int? level,
    int? sortOrder,
    String? icon,
    String? iconType,
    String? customIconPath,
    String? iconCloudFileId,
    String? iconCloudSha256,
    String? parentName,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeUpdateCategory(
      ledgerId: ledgerId,
      categoryId: categoryId,
      baseChangeId: baseChangeId,
      name: name,
      kind: kind,
      level: level,
      sortOrder: sortOrder,
      icon: icon,
      iconType: iconType,
      customIconPath: customIconPath,
      iconCloudFileId: iconCloudFileId,
      iconCloudSha256: iconCloudSha256,
      parentName: parentName,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeDeleteCategory({
    required String ledgerId,
    required String categoryId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeDeleteCategory(
      ledgerId: ledgerId,
      categoryId: categoryId,
      baseChangeId: baseChangeId,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeCreateTag({
    required String ledgerId,
    required int baseChangeId,
    required String name,
    String? color,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeCreateTag(
      ledgerId: ledgerId,
      baseChangeId: baseChangeId,
      name: name,
      color: color,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeUpdateTag({
    required String ledgerId,
    required String tagId,
    required int baseChangeId,
    String? name,
    String? color,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeUpdateTag(
      ledgerId: ledgerId,
      tagId: tagId,
      baseChangeId: baseChangeId,
      name: name,
      color: color,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeDeleteTag({
    required String ledgerId,
    required String tagId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'BeeCount Cloud storage is not initialized.');
    }
    return storage.writeDeleteTag(
      ledgerId: ledgerId,
      tagId: tagId,
      baseChangeId: baseChangeId,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }
}

class _BeeCountDeviceMetadata {
  const _BeeCountDeviceMetadata({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    this.appVersion,
    this.osVersion,
    this.deviceModel,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String? appVersion;
  final String? osVersion;
  final String? deviceModel;
}

String? _trimOrNull(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String _firstNonEmpty(List<String?> values, {required String fallback}) {
  for (final value in values) {
    final normalized = _trimOrNull(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return fallback;
}

String _joinNonEmpty(List<String?> values) {
  return values
      .map(_trimOrNull)
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .join(' ')
      .trim();
}

class BeeCountCloudAuthService implements CloudAuthService {
  BeeCountCloudAuthService({
    required this.baseUrl,
    required this.apiPrefix,
    http.Client? httpClient,
    TwoFactorChallengeHandler? twoFactorHandler,
  })  : _httpClient = httpClient ?? http.Client(),
        _twoFactorHandler = twoFactorHandler;

  final String baseUrl;
  final String apiPrefix;
  final http.Client _httpClient;
  final TwoFactorChallengeHandler? _twoFactorHandler;

  final StreamController<CloudUser?> _authStateController =
      StreamController<CloudUser?>.broadcast();

  _BeeCountCloudSession? _session;
  _BeeCountDeviceMetadata? _deviceMetadataCache;
  Future<_BeeCountDeviceMetadata>? _deviceMetadataFuture;

  /// 离线恢复凭证:token 全部失效(refresh_token 过期 / server 认不出来)时,
  /// 如果注入了邮密,currentUser/requireAccessToken 会用这对凭证自动再登一次,
  /// 让 API 调用方无感恢复,不用用户手动去配置页点确定。
  String? _recoveryEmail;
  String? _recoveryPassword;
  Future<CloudUser>? _recoveryInFlight;

  /// 静默恢复失败后冷却到这个时间点,期间所有 currentUser / requireAccessToken
  /// 调用都直接返 null,**不再发新的 /auth/login 请求**。
  /// 防止 UI 频繁 rebuild 导致 silent recovery 狂打 login 撞上 server 30/min 限流,
  /// 后果是用户主动点「重新登录」时反而被 429 挡掉。
  /// 触发场景:
  ///   - 服务端开了 2FA,silent 模式拿到 requires_2fa=true 后立即 cancel
  ///   - 邮密被改了 / 账号被禁
  ///   - server 暂时 5xx
  /// 登录成功后会清掉(见 _saveSession)。
  DateTime? _silentRecoveryCooldownUntil;
  static const _silentRecoveryCooldown = Duration(seconds: 30);

  void setRecoveryCredentials({String? email, String? password}) {
    _recoveryEmail = (email != null && email.isNotEmpty) ? email : null;
    _recoveryPassword =
        (password != null && password.isNotEmpty) ? password : null;
    // 凭证更新 = 用户在 cloud 配置页保存了新邮密 / 切回 BeeCount,清掉旧冷却,
    // 让下一次 currentUser 立刻尝试一次新凭证的登录。
    _silentRecoveryCooldownUntil = null;
  }

  String get _sessionStorageKey {
    final raw = '$baseUrl|$apiPrefix';
    final digest = sha1.convert(utf8.encode(raw)).toString();
    return 'beecount_cloud_session_$digest';
  }

  String get _localDeviceIdStorageKey {
    final raw = '$baseUrl|$apiPrefix';
    final digest = sha1.convert(utf8.encode(raw)).toString();
    return 'beecount_cloud_local_device_id_$digest';
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _session = _BeeCountCloudSession.fromJson(json);
      if (_isAccessTokenExpired(_session!)) {
        await _refreshSessionOrClear();
      } else {
        _emitCurrentUser();
      }
    } catch (_) {
      await _clearSession();
    }
  }

  @override
  Stream<CloudUser?> get authStateChanges => _authStateController.stream;

  @override
  Future<CloudUser?> get currentUser async {
    final session = _session;
    if (session == null) {
      // 完全没 session(从没登过 / session 被清了):只有带了恢复凭证才尝试
      // 自动重登,否则按未登录返回 null 让 UI 显示登录入口。
      return _tryRecoveryLogin();
    }
    if (_isAccessTokenExpired(session)) {
      final refreshed = await tryRefreshSession();
      if (!refreshed) {
        // refresh 失败 → 凭证兜底。
        return _tryRecoveryLogin();
      }
    }
    final latest = _session;
    if (latest == null) return null;
    return _toCloudUser(latest);
  }

  Future<String> requireAccessToken() async {
    final session = _session;
    if (session == null) {
      final recovered = await _tryRecoveryLogin();
      if (recovered == null || _session == null) {
        throw CloudNotAuthenticatedException();
      }
      return _session!.accessToken;
    }
    if (_isAccessTokenExpired(session)) {
      final refreshed = await tryRefreshSession();
      if (!refreshed || _session == null) {
        final recovered = await _tryRecoveryLogin();
        if (recovered == null || _session == null) {
          throw CloudNotAuthenticatedException(
              'Session expired, please login again.');
        }
        return _session!.accessToken;
      }
    }
    return _session!.accessToken;
  }

  /// 凭恢复邮密自动重登一次。并发多次调用只跑一个请求,其他调用方共享结果。
  /// 没邮密 / 登录失败都返回 null(不抛),让上层按"未登录"路径处理。
  ///
  /// 失败后进 30 秒冷却期(见 [_silentRecoveryCooldownUntil] 注释):
  /// 防止 UI 频繁 rebuild 导致每次都 POST /auth/login,撞 server 30/min 限流,
  /// 让用户主动点「重新登录」时反而被 429 挡掉。
  Future<CloudUser?> _tryRecoveryLogin() async {
    final email = _recoveryEmail;
    final password = _recoveryPassword;
    if (email == null || password == null) return null;

    // 冷却期内直接返 null,不打网络请求
    final cooldown = _silentRecoveryCooldownUntil;
    if (cooldown != null && DateTime.now().isBefore(cooldown)) {
      return null;
    }

    final existing = _recoveryInFlight;
    if (existing != null) {
      try {
        return await existing;
      } catch (_) {
        return null;
      }
    }
    // 后台恢复用 silent 模式:遇到 2FA 不弹 dialog,直接当登录失败处理,
    // 让用户在 sync page 主动点「重新登录」时再触发。
    final future =
        _signInWithEmailSilent(email: email, password: password);
    _recoveryInFlight = future;
    try {
      return await future;
    } catch (_) {
      // 失败 → 启冷却,30 秒内别再敲 server
      _silentRecoveryCooldownUntil =
          DateTime.now().add(_silentRecoveryCooldown);
      return null;
    } finally {
      _recoveryInFlight = null;
    }
  }

  String? get currentDeviceId => _session?.deviceId;
  String? get currentUserId => _session?.userId;

  /// Refresh 请求去重的 in-flight future。
  ///
  /// server 用 rotating refresh token:每次 /auth/refresh 都旋转 — 老 token 立刻
  /// revoke,返回新 token。如果 cold start 时 initialize() 看到 access_token 过期
  /// 同步触发一次 refresh,UI 又同时调 currentUser/requireAccessToken 触发另一次,
  /// 两个 POST 用的是 SAME 老 refresh_token → 第一个成功(新 token 入库,老 token
  /// revoke)→ 第二个用已 revoke 的老 token → 401 → _clearSession() 把刚保存的
  /// 新 session 也清掉。下次启动就回到"silent recovery 撞 2FA"的循环。
  ///
  /// 用 in-flight dedup 让并发调用共享同一个 refresh future,只发一次 server 请求。
  Future<bool>? _refreshInFlight;

  Future<bool> tryRefreshSession() async {
    final existing = _refreshInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _doRefreshSession();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _doRefreshSession() async {
    try {
      await _refreshSession();
      return true;
    } catch (_) {
      await _clearSession();
      return false;
    }
  }

  Future<Map<String, dynamic>> _buildAuthBody({
    required String email,
    required String password,
  }) async {
    final metadata = await _resolveDeviceMetadata();
    return <String, dynamic>{
      'email': email,
      'password': password,
      'device_id': metadata.deviceId,
      'device_name': metadata.deviceName,
      'platform': metadata.platform,
      if (metadata.appVersion != null) 'app_version': metadata.appVersion,
      if (metadata.osVersion != null) 'os_version': metadata.osVersion,
      if (metadata.deviceModel != null) 'device_model': metadata.deviceModel,
    };
  }

  Future<_BeeCountDeviceMetadata> _resolveDeviceMetadata() {
    final cached = _deviceMetadataCache;
    if (cached != null) {
      return Future.value(cached);
    }
    final inflight = _deviceMetadataFuture;
    if (inflight != null) {
      return inflight;
    }
    final future = _loadDeviceMetadata();
    _deviceMetadataFuture = future;
    return future.then((value) {
      _deviceMetadataCache = value;
      _deviceMetadataFuture = null;
      return value;
    }).catchError((error) {
      _deviceMetadataFuture = null;
      throw error;
    });
  }

  Future<_BeeCountDeviceMetadata> _loadDeviceMetadata() async {
    final localDeviceId = await _resolveOrCreateLocalDeviceId();
    String deviceName = 'BeeCount App';
    String platform = 'flutter';
    String? appVersion;
    String? osVersion;
    String? deviceModel;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = _trimOrNull(packageInfo.version);
      final buildNumber = _trimOrNull(packageInfo.buildNumber);
      appVersion = _trimOrNull(_joinNonEmpty([version, buildNumber]));
      deviceName = _firstNonEmpty(
        [packageInfo.appName, deviceName],
        fallback: deviceName,
      );
    } catch (_) {
      // Ignore package info failure and fall back to defaults.
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final web = await deviceInfo.webBrowserInfo;
        platform = 'web';
        osVersion = _trimOrNull(web.platform);
        deviceModel = _trimOrNull(web.userAgent);
        deviceName = _firstNonEmpty(
          [
            web.browserName.name,
            deviceName,
          ],
          fallback: deviceName,
        );
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final info = await deviceInfo.androidInfo;
            platform = 'android';
            osVersion = _joinNonEmpty(
              ['Android', _trimOrNull(info.version.release)],
            );
            deviceModel = _joinNonEmpty([
              _trimOrNull(info.brand),
              _trimOrNull(info.model),
            ]);
            deviceName = _firstNonEmpty(
              [info.brand, info.model, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.iOS:
            final info = await deviceInfo.iosInfo;
            platform = 'ios';
            osVersion = _joinNonEmpty([
              _trimOrNull(info.systemName),
              _trimOrNull(info.systemVersion),
            ]);
            deviceModel = _joinNonEmpty([
              _trimOrNull(info.model),
              _trimOrNull(info.utsname.machine),
            ]);
            deviceName = _firstNonEmpty(
              [info.name, info.model, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.macOS:
            final info = await deviceInfo.macOsInfo;
            platform = 'macos';
            osVersion = _joinNonEmpty([
              _trimOrNull(info.osRelease),
              _trimOrNull(info.arch),
            ]);
            deviceModel = _joinNonEmpty([
              _trimOrNull(info.model),
              _trimOrNull(info.hostName),
            ]);
            deviceName = _firstNonEmpty(
              [info.computerName, info.model, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.windows:
            final info = await deviceInfo.windowsInfo;
            platform = 'windows';
            osVersion = _joinNonEmpty([
              _trimOrNull(info.displayVersion),
              _trimOrNull(info.releaseId),
            ]);
            deviceModel = _joinNonEmpty([
              _trimOrNull(info.productName),
              _trimOrNull(info.deviceId),
            ]);
            deviceName = _firstNonEmpty(
              [info.computerName, info.productName, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.linux:
            final info = await deviceInfo.linuxInfo;
            platform = 'linux';
            osVersion = _joinNonEmpty([
              _trimOrNull(info.prettyName),
              _trimOrNull(info.version),
            ]);
            deviceModel = _joinNonEmpty([
              _trimOrNull(info.machineId),
              _trimOrNull(info.id),
            ]);
            deviceName = _firstNonEmpty(
              [info.name, info.prettyName, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.fuchsia:
            platform = 'fuchsia';
            break;
        }
      }
    } catch (_) {
      // Ignore device info failure and keep fallback values.
    }

    return _BeeCountDeviceMetadata(
      deviceId: localDeviceId,
      deviceName: deviceName,
      platform: platform,
      appVersion: _trimOrNull(appVersion),
      osVersion: _trimOrNull(osVersion),
      deviceModel: _trimOrNull(deviceModel),
    );
  }

  Future<String> _resolveOrCreateLocalDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = _trimOrNull(prefs.getString(_localDeviceIdStorageKey));
    if (existing != null) {
      return existing;
    }
    final next = _generateLocalDeviceId();
    await prefs.setString(_localDeviceIdStorageKey, next);
    return next;
  }

  String _generateLocalDeviceId() {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    final digest = sha1
        .convert(utf8.encode(
            '$baseUrl|$apiPrefix|$now|${DateTime.now().millisecondsSinceEpoch}'))
        .toString();
    return 'dev_${digest.substring(0, 32)}';
  }

  @override
  Future<CloudUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final body = await _buildAuthBody(email: email, password: password);
    final session = await _authenticate(
      path: '/auth/login',
      body: body,
      actionName: 'login',
    );
    return _toCloudUser(session);
  }

  /// 内部用:登录但**不弹** 2FA dialog。供后台 token recovery / 自动登录场景调用,
  /// 避免用户没主动操作就被弹出输码框。如果服务端要求 2FA 而我们处于 silent 模式,
  /// 抛 [TwoFactorCancelledException],调用方用 try/catch 当作"恢复失败"处理,
  /// 让 UI 上的「重新登录」按钮继续兜底(那条路径走的是公开 signInWithEmail,会弹)。
  Future<CloudUser> _signInWithEmailSilent({
    required String email,
    required String password,
  }) async {
    final body = await _buildAuthBody(email: email, password: password);
    final session = await _authenticate(
      path: '/auth/login',
      body: body,
      actionName: 'login',
      silent2fa: true,
    );
    return _toCloudUser(session);
  }

  @override
  Future<CloudUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final body = await _buildAuthBody(email: email, password: password);
    final session = await _authenticate(
      path: '/auth/register',
      body: body,
      actionName: 'register',
    );
    return _toCloudUser(session);
  }

  @override
  Future<void> signOut() async {
    final session = _session;
    if (session == null) {
      return;
    }

    try {
      await _request(
        method: 'POST',
        path: '/auth/logout',
        body: {'refresh_token': session.refreshToken},
        accessToken: session.accessToken,
      );
    } catch (_) {
      // Ignore network/logout errors and clear local session directly.
    } finally {
      await _clearSession();
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    throw CloudAuthException(
        'BeeCount Cloud v1 does not support password reset.');
  }

  @override
  Future<void> resendEmailVerification({required String email}) async {
    throw CloudAuthException(
        'BeeCount Cloud v1 does not require email verification.');
  }

  void dispose() {
    _authStateController.close();
    _httpClient.close();
  }

  Future<_BeeCountCloudSession> _authenticate({
    required String path,
    required Map<String, dynamic> body,
    required String actionName,
    bool silent2fa = false,
  }) async {
    final response = await _request(method: 'POST', path: path, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAuthException(
          '${actionName[0].toUpperCase()}${actionName.substring(1)} failed: ${_extractErrorMessage(response)}');
    }

    final payload = _decodeJsonObject(response.body);

    // server 返回 requires_2fa=true → 弹 challenge UI 拿 6 位码,POST /auth/2fa/verify
    // 兑换真 token。register 不会要 2FA(新用户尚未启用),仅 login 路径会进这个分支。
    if (payload['requires_2fa'] == true) {
      // 后台 token recovery / 自动恢复登录场景:silent2fa=true,直接跑 cancel 异常,
      // 不弹 dialog。让 UI 上的「重新登录」按钮触发用户感知到的登录,那条路径走的是
      // 公开 signInWithEmail,会正常弹。
      if (silent2fa) {
        throw const TwoFactorCancelledException(
            '2FA required but skipped in silent recovery mode');
      }
      return _handleTwoFactorChallenge(
        loginBody: body,
        challengePayload: payload,
      );
    }

    final session = _BeeCountCloudSession.fromAuthResponse(payload);
    await _saveSession(session);
    return session;
  }

  Future<_BeeCountCloudSession> _handleTwoFactorChallenge({
    required Map<String, dynamic> loginBody,
    required Map<String, dynamic> challengePayload,
  }) async {
    final challengeToken = challengePayload['challenge_token'];
    if (challengeToken is! String || challengeToken.isEmpty) {
      throw CloudAuthException(
          'Login response advertised requires_2fa but no challenge_token.');
    }
    final rawMethods = challengePayload['available_methods'];
    final methods = (rawMethods is List)
        ? rawMethods.whereType<String>().toList()
        : <String>['totp', 'recovery_code'];

    final handler = _twoFactorHandler;
    if (handler == null) {
      throw CloudAuthException(
          'Server requires 2FA but no TwoFactorChallengeHandler is registered. '
          'Set BeeCountCloudProvider.globalTwoFactorHandler at app startup.');
    }

    // verify callback:UI 输完码点验证 → 调这个 → 命中就保存 session,
    // 返回 null,UI 关闭;失败返回 server 错误消息,UI 就地展示让用户重试。
    _BeeCountCloudSession? successSession;

    Future<String?> verify(String method, String code) async {
      final verifyBody = Map<String, dynamic>.of(loginBody)
        ..remove('email')
        ..remove('password');
      verifyBody['challenge_token'] = challengeToken;
      verifyBody['method'] = method;
      verifyBody['code'] = code;
      verifyBody['client_type'] ??= 'app';

      final verifyResp = await _request(
        method: 'POST',
        path: '/auth/2fa/verify',
        body: verifyBody,
      );
      if (verifyResp.statusCode < 200 || verifyResp.statusCode >= 300) {
        return _extractErrorMessage(verifyResp);
      }
      final verifyPayload = _decodeJsonObject(verifyResp.body);
      final session = _BeeCountCloudSession.fromAuthResponse(verifyPayload);
      await _saveSession(session);
      successSession = session;
      return null;
    }

    final ok = await handler(TwoFactorChallengeRequest(
      challengeToken: challengeToken,
      availableMethods: methods,
      email: (loginBody['email'] as String?) ?? '',
      verify: verify,
    ));
    if (!ok || successSession == null) {
      throw const TwoFactorCancelledException();
    }
    return successSession!;
  }

  /// GET /auth/2fa/status — UI 用来在云同步页展示「已启用 ✓ / 未启用」状态行。
  Future<TwoFactorStatus> getTwoFactorStatus() async {
    final accessToken = await requireAccessToken();
    final response = await _request(
      method: 'GET',
      path: '/auth/2fa/status',
      accessToken: accessToken,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAuthException(
          'Get 2FA status failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    final enabledAtRaw = payload['enabled_at'];
    DateTime? enabledAt;
    if (enabledAtRaw is String && enabledAtRaw.isNotEmpty) {
      enabledAt = DateTime.tryParse(enabledAtRaw)?.toLocal();
    }
    return TwoFactorStatus(
      enabled: payload['enabled'] == true,
      enabledAt: enabledAt,
    );
  }

  Future<void> _refreshSessionOrClear() async {
    // 走 tryRefreshSession 拿到 in-flight 去重保护,避免跟 currentUser/requireAccessToken
    // 并发的 refresh 撞 server 的 rotating refresh token 机制。
    await tryRefreshSession();
  }

  Future<void> _refreshSession() async {
    final session = _session;
    if (session == null) {
      throw CloudNotAuthenticatedException();
    }

    final response = await _request(
      method: 'POST',
      path: '/auth/refresh',
      body: {'refresh_token': session.refreshToken},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAuthException(
          'Refresh token failed: ${_extractErrorMessage(response)}');
    }

    final payload = _decodeJsonObject(response.body);
    final refreshed = _BeeCountCloudSession.fromAuthResponse(payload);
    await _saveSession(refreshed);
  }

  Future<void> _saveSession(_BeeCountCloudSession session) async {
    _session = session;
    // 任何成功登录路径都清掉静默恢复冷却,避免之前的失败状态拖到现在。
    _silentRecoveryCooldownUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionStorageKey, jsonEncode(session.toJson()));
    await prefs.setString(_localDeviceIdStorageKey, session.deviceId);
    final metadata = _deviceMetadataCache;
    if (metadata != null && metadata.deviceId != session.deviceId) {
      _deviceMetadataCache = _BeeCountDeviceMetadata(
        deviceId: session.deviceId,
        deviceName: metadata.deviceName,
        platform: metadata.platform,
        appVersion: metadata.appVersion,
        osVersion: metadata.osVersion,
        deviceModel: metadata.deviceModel,
      );
    }
    _emitCurrentUser();
  }

  Future<void> _clearSession() async {
    _session = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionStorageKey);
    _authStateController.add(null);
  }

  void _emitCurrentUser() {
    final session = _session;
    if (session == null) {
      _authStateController.add(null);
      return;
    }
    _authStateController.add(_toCloudUser(session));
  }

  CloudUser _toCloudUser(_BeeCountCloudSession session) {
    return CloudUser(
      id: session.userId,
      email: session.email,
      metadata: {
        'provider': 'beecount_cloud',
        'deviceId': session.deviceId,
      },
    );
  }

  bool _isAccessTokenExpired(_BeeCountCloudSession session) {
    final now = DateTime.now().toUtc();
    return now.isAfter(
        session.accessTokenExpiresAt.subtract(const Duration(seconds: 30)));
  }

  Future<http.Response> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl$apiPrefix$path');
    final request = http.Request(method, uri);
    request.headers['Content-Type'] = 'application/json';
    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamed = await _httpClient.send(request);
    return http.Response.fromStream(streamed);
  }
}

class BeeCountCloudStorageService implements CloudStorageService {
  BeeCountCloudStorageService({
    required this.baseUrl,
    required this.apiPrefix,
    required this.auth,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiPrefix;
  final BeeCountCloudAuthService auth;
  final http.Client _httpClient;

  void dispose() {
    _httpClient.close();
  }

  String? _normalizeAbsoluteUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return parsed.toString();
    }
    final normalizedBase = baseUrl.trim();
    if (normalizedBase.isEmpty) {
      return trimmed;
    }
    final base = Uri.parse(
      normalizedBase.endsWith('/') ? normalizedBase : '$normalizedBase/',
    );
    if (parsed != null) {
      if (!parsed.hasScheme && parsed.hasAuthority) {
        final fallbackScheme = base.scheme.isNotEmpty ? base.scheme : 'https';
        return parsed.replace(scheme: fallbackScheme).toString();
      }
      return base.resolveUri(parsed).toString();
    }
    return base.resolve(trimmed).toString();
  }

  Map<String, dynamic> _copyWithNormalizedUrl(
    Map<String, dynamic> source,
    String key,
  ) {
    final raw = source[key];
    final normalized = raw is String ? _normalizeAbsoluteUrl(raw) : null;
    if (raw == normalized) {
      return source;
    }
    final out = Map<String, dynamic>.from(source);
    out[key] = normalized;
    return out;
  }

  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async {
    final ledgerId = _ledgerIdFromPath(path);
    // 先确保 session 有效（触发 token refresh），再读 deviceId
    await auth.requireAccessToken();
    final deviceId = auth.currentDeviceId;
    if (deviceId == null || deviceId.isEmpty) {
      throw CloudNotAuthenticatedException(
          'Missing device id, please login again.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final response = await _authedRequest(
      method: 'POST',
      path: '/sync/push',
      body: {
        'device_id': deviceId,
        'changes': [
          {
            'ledger_id': ledgerId,
            'entity_type': 'ledger_snapshot',
            'entity_sync_id': ledgerId,
            'action': 'upsert',
            'payload': {
              'content': data,
              'metadata': metadata ?? <String, String>{},
            },
            'updated_at': now,
          }
        ]
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Upload failed: ${_extractErrorMessage(response)}');
    }
  }

  @override
  Future<String?> download({required String path}) async {
    final ledgerId = _ledgerIdFromPath(path);
    final response = await _authedRequest(
      method: 'GET',
      path: '/sync/full',
      query: {'ledger_id': ledgerId},
    );

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Download failed: ${_extractErrorMessage(response)}');
    }

    final payload = _decodeJsonObject(response.body);
    final snapshot = payload['snapshot'];
    if (snapshot == null || snapshot is! Map<String, dynamic>) {
      return null;
    }

    final changePayload = snapshot['payload'];
    if (changePayload is! Map<String, dynamic>) {
      return null;
    }
    final content = changePayload['content'];
    return content is String ? content : null;
  }

  @override
  Future<void> delete({required String path}) async {
    final ledgerId = _ledgerIdFromPath(path);
    // 先确保 session 有效（触发 token refresh），再读 deviceId
    await auth.requireAccessToken();
    final deviceId = auth.currentDeviceId;
    if (deviceId == null || deviceId.isEmpty) {
      throw CloudNotAuthenticatedException(
          'Missing device id, please login again.');
    }

    final response = await _authedRequest(
      method: 'POST',
      path: '/sync/push',
      body: {
        'device_id': deviceId,
        'changes': [
          {
            'ledger_id': ledgerId,
            'entity_type': 'ledger_snapshot',
            'entity_sync_id': ledgerId,
            'action': 'delete',
            'payload': <String, dynamic>{},
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }
        ]
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Delete failed: ${_extractErrorMessage(response)}');
    }
  }

  @override
  Future<List<CloudFile>> list({required String path}) async {
    final prefix = PathHelper.normalize(path);
    final response = await _authedRequest(method: 'GET', path: '/sync/ledgers');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'List failed: ${_extractErrorMessage(response)}');
    }

    final data = jsonDecode(response.body);
    if (data is! List) {
      return const [];
    }

    final files = <CloudFile>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final ledgerId = item['ledger_id'];
      if (ledgerId is! String || ledgerId.isEmpty) continue;

      if (prefix.isNotEmpty && !ledgerId.startsWith(prefix)) {
        continue;
      }

      final updatedAtRaw = item['updated_at'];
      DateTime? updatedAt;
      if (updatedAtRaw is String && updatedAtRaw.isNotEmpty) {
        updatedAt = DateTime.tryParse(updatedAtRaw)?.toLocal();
      }

      final metadata = item['metadata'];
      files.add(
        CloudFile(
          name: ledgerId,
          path: ledgerId,
          size: (item['size'] as num?)?.toInt(),
          lastModified: updatedAt,
          metadata: metadata is Map<String, dynamic> ? metadata : const {},
        ),
      );
    }
    return files;
  }

  @override
  Future<bool> exists({required String path}) async {
    final metadata = await getMetadata(path: path);
    return metadata != null;
  }

  @override
  Future<CloudFile?> getMetadata({required String path}) async {
    final target = PathHelper.normalize(path);
    if (target.isEmpty) return null;

    final files = await list(path: '');
    for (final file in files) {
      if (PathHelper.normalize(file.path) == target ||
          PathHelper.normalize(file.name) == target) {
        return file;
      }
    }
    return null;
  }

  Future<BeeCountCloudPullResult> pullChanges({
    int? since,
    int limit = 1000,
  }) async {
    final currentCursor = since ?? await _loadCursor();
    final query = <String, String>{
      'since': '$currentCursor',
      'limit': '$limit',
    };
    final deviceId = auth.currentDeviceId;
    if (deviceId != null && deviceId.isNotEmpty) {
      query['device_id'] = deviceId;
    }

    final response = await _authedRequest(
      method: 'GET',
      path: '/sync/pull',
      query: query,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Pull failed: ${_extractErrorMessage(response)}');
    }

    final payload = _decodeJsonObject(response.body);
    final rawChanges = payload['changes'];
    final nextCursor =
        (payload['server_cursor'] as num?)?.toInt() ?? currentCursor;
    final hasMore = payload['has_more'] == true;

    final changes = <BeeCountCloudSyncChange>[];
    if (rawChanges is List) {
      for (final row in rawChanges) {
        if (row is! Map<String, dynamic>) {
          continue;
        }
        final changeId = (row['change_id'] as num?)?.toInt();
        final ledgerId = row['ledger_id'];
        final entityType = row['entity_type'];
        final entitySyncId = row['entity_sync_id'];
        final action = row['action'];
        if (changeId == null ||
            ledgerId is! String ||
            entityType is! String ||
            entitySyncId is! String ||
            action is! String) {
          continue;
        }
        final rawPayload = row['payload'];
        changes.add(
          BeeCountCloudSyncChange(
            changeId: changeId,
            ledgerId: ledgerId,
            entityType: entityType,
            entitySyncId: entitySyncId,
            action: action,
            updatedByDeviceId: row['updated_by_device_id'] as String?,
            updatedAt: row['updated_at'] as String?,
            payload: rawPayload is Map<String, dynamic> ? rawPayload : null,
          ),
        );
      }
    }

    await _saveCursor(nextCursor);
    return BeeCountCloudPullResult(
      changes: changes,
      serverCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  /// 推送增量变更（个体实体级别，非 ledger_snapshot 包装）
  Future<void> pushEntityChanges({
    required List<Map<String, dynamic>> changes,
  }) async {
    if (changes.isEmpty) return;
    // 先确保 session 有效（触发 token refresh），再读 deviceId
    await auth.requireAccessToken();
    final deviceId = auth.currentDeviceId;
    debugPrint('[BCC] pushEntityChanges: ${changes.length} changes, deviceId=$deviceId');
    if (deviceId == null || deviceId.isEmpty) {
      debugPrint('[BCC] pushEntityChanges: deviceId 为空，抛出认证异常');
      throw CloudNotAuthenticatedException(
          'Missing device id, please login again.');
    }
    final response = await _authedRequest(
      method: 'POST',
      path: '/sync/push',
      body: {
        'device_id': deviceId,
        'changes': changes,
      },
    );
    final bodyPreview = response.body.length > 200
        ? response.body.substring(0, 200)
        : response.body;
    debugPrint('[BCC] pushEntityChanges response: ${response.statusCode} $bodyPreview');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Push entity changes failed (${response.statusCode}): ${_extractErrorMessage(response)}');
    }
  }

  Future<Map<String, BeeCountCloudAttachmentExistsItem>> attachmentBatchExists({
    required String ledgerId,
    required List<String> sha256List,
  }) async {
    final wanted = sha256List
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (wanted.isEmpty) {
      return const {};
    }
    final response = await _authedRequest(
      method: 'POST',
      path: '/attachments/batch-exists',
      body: {
        'ledger_id': ledgerId,
        'sha256_list': wanted,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Attachment batch exists failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    final itemsRaw = payload['items'];
    final result = <String, BeeCountCloudAttachmentExistsItem>{};
    if (itemsRaw is List) {
      for (final row in itemsRaw) {
        if (row is! Map<String, dynamic>) continue;
        final item = BeeCountCloudAttachmentExistsItem.fromJson(row);
        result[item.sha256] = item;
      }
    }
    return result;
  }

  Future<BeeCountCloudProfile> getMyProfile() async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/profile/me',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Get profile failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return BeeCountCloudProfile.fromJson(
      _copyWithNormalizedUrl(payload, 'avatar_url'),
    );
  }

  Future<BeeCountCloudProfile> updateMyProfileDisplayName({
    required String displayName,
  }) async {
    final normalized = displayName.trim();
    if (normalized.isEmpty) {
      throw CloudStorageException('Update profile failed: empty display name');
    }
    return _patchMyProfile(body: {'display_name': normalized});
  }

  /// 推送收支颜色方案偏好到服务端。mobile 端 `incomeExpenseColorSchemeProvider`
  /// 切换时 fire-and-forget 调一下，让 web 端通过 WS profile_change 同步。
  /// `incomeIsRed` true = 红色收入 / 绿色支出（mobile 默认）。
  Future<BeeCountCloudProfile> updateMyProfileIncomeColorScheme({
    required bool incomeIsRed,
  }) async {
    return _patchMyProfile(body: {'income_is_red': incomeIsRed});
  }

  /// 推送主题色到服务端。`hex` 形如 `#F59E0B`(server 会校验 `#RRGGBB`)。
  /// 同步方向是单向的:mobile → server → web。web 本地改主题色不回推。
  Future<BeeCountCloudProfile> updateMyProfileThemeColor({
    required String hex,
  }) async {
    return _patchMyProfile(body: {'theme_primary_color': hex});
  }

  /// 推送外观类设置(header_decoration_style / compact_amount /
  /// show_transaction_time 等)到服务端。传整个 dict 整体替换;server 侧
  /// appearance_json 字段会整包写入。空 dict 视为清空。
  Future<BeeCountCloudProfile> updateMyProfileAppearance({
    required Map<String, dynamic> appearance,
  }) async {
    return _patchMyProfile(body: {'appearance': appearance});
  }

  /// 推送 AI 配置(providers 数组 + binding + custom_prompt + strategy 等)
  /// 到 server。整包替换,空 dict 视为清空。
  Future<BeeCountCloudProfile> updateMyProfileAiConfig({
    required Map<String, dynamic> aiConfig,
  }) async {
    return _patchMyProfile(body: {'ai_config': aiConfig});
  }

  /// PATCH /profile/me 通用封装，body 里写哪些字段就更新哪些；server 端会
  /// 忽略 None 值，只 merge 显式给出的键。返回 server 上新的 profile。
  Future<BeeCountCloudProfile> _patchMyProfile({
    required Map<String, dynamic> body,
  }) async {
    final response = await _authedRequest(
      method: 'PATCH',
      path: '/profile/me',
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Update profile failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return BeeCountCloudProfile.fromJson(
      _copyWithNormalizedUrl(payload, 'avatar_url'),
    );
  }

  Future<BeeCountCloudAvatarUploadResult> uploadMyAvatar({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw CloudStorageException('Avatar upload failed: empty file');
    }
    var token = await auth.requireAccessToken();
    var response = await _profileAvatarMultipartRequest(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      token: token,
    );
    if (response.statusCode == 401) {
      final refreshed = await auth.tryRefreshSession();
      if (!refreshed) {
        throw CloudNotAuthenticatedException(
            'Session expired, please login again.');
      }
      token = await auth.requireAccessToken();
      response = await _profileAvatarMultipartRequest(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        token: token,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Avatar upload failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return BeeCountCloudAvatarUploadResult.fromJson(
      _copyWithNormalizedUrl(payload, 'avatar_url'),
    );
  }

  Future<BeeCountCloudAttachmentUploadResult> uploadAttachment({
    required String ledgerId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw CloudStorageException('Attachment upload failed: empty file');
    }
    var token = await auth.requireAccessToken();
    var response = await _multipartRequest(
      ledgerId: ledgerId,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      token: token,
    );
    if (response.statusCode == 401) {
      final refreshed = await auth.tryRefreshSession();
      if (!refreshed) {
        throw CloudNotAuthenticatedException(
            'Session expired, please login again.');
      }
      token = await auth.requireAccessToken();
      response = await _multipartRequest(
        ledgerId: ledgerId,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        token: token,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Attachment upload failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return BeeCountCloudAttachmentUploadResult.fromJson(payload);
  }

  /// 上传分类自定义图标(user-global,不绑 ledger)。
  ///
  /// 走专用 endpoint `/attachments/category-icons/upload`,server 端按
  /// (user_id, sha256) 去重,落库 attachment_files 行的 ledger_id=NULL、
  /// attachment_kind='category_icon'。跨账本只需上传一次,避免历史按 ledger
  /// 重复上传 N 份的问题。
  Future<BeeCountCloudAttachmentUploadResult> uploadCategoryIcon({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw CloudStorageException('Category icon upload failed: empty file');
    }
    var token = await auth.requireAccessToken();
    var response = await _categoryIconMultipartRequest(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      token: token,
    );
    if (response.statusCode == 401) {
      final refreshed = await auth.tryRefreshSession();
      if (!refreshed) {
        throw CloudNotAuthenticatedException(
            'Session expired, please login again.');
      }
      token = await auth.requireAccessToken();
      response = await _categoryIconMultipartRequest(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        token: token,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Category icon upload failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return BeeCountCloudAttachmentUploadResult.fromJson(payload);
  }

  Future<Uint8List> downloadAttachment({required String fileId}) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/attachments/$fileId',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Attachment download failed: ${_extractErrorMessage(response)}');
    }
    return response.bodyBytes;
  }

  Future<Uint8List> downloadMyAvatar({
    required String userId,
    int? version,
  }) async {
    // 服务端这个 endpoint 不校验 auth（profile.py download_avatar 无
    // Depends(get_current_user)），但复用 _authedRequest 统一走同一套 base
    // URL + header 拼接，auth header 即使带了也无害。
    final response = await _authedRequest(
      method: 'GET',
      path: '/profile/avatar/$userId',
      query: version != null ? {'v': '$version'} : null,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Avatar download failed: ${_extractErrorMessage(response)}');
    }
    return response.bodyBytes;
  }

  Future<List<BeeCountCloudDevice>> listDevices({
    String view = 'deduped',
    int activeWithinDays = 30,
  }) async {
    final normalizedView =
        view.trim().toLowerCase() == 'sessions' ? 'sessions' : 'deduped';
    final normalizedDays = activeWithinDays < 0 ? 0 : activeWithinDays;
    final response = await _authedRequest(
      method: 'GET',
      path: '/devices',
      query: {
        'view': normalizedView,
        'active_within_days': '$normalizedDays',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'List devices failed: ${_extractErrorMessage(response)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final out = <BeeCountCloudDevice>[];
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) continue;
      out.add(BeeCountCloudDevice.fromJson(row));
    }
    return out;
  }

  Future<void> revokeDevice({required String deviceId}) async {
    final response = await _authedRequest(
      method: 'POST',
      path: '/devices/$deviceId/revoke',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Revoke device failed: ${_extractErrorMessage(response)}');
    }
  }

  Future<List<BeeCountCloudReadLedger>> readLedgers() async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/ledgers',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Read ledgers failed: ${_extractErrorMessage(response)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final out = <BeeCountCloudReadLedger>[];
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) continue;
      out.add(BeeCountCloudReadLedger.fromJson(row));
    }
    return out;
  }

  Future<BeeCountCloudReadLedgerDetail> readLedgerDetail({
    required String ledgerId,
  }) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/ledgers/$ledgerId',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Read ledger detail failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return BeeCountCloudReadLedgerDetail.fromJson(payload);
  }

  /// 读 server 上某账本的实体计数(tx / attachment / budget)。给"深度同步检测"
  /// 用,mobile 对比本地 Drift 计数就能判断是否需要触发一次完整 sync。
  Future<BeeCountCloudLedgerStats> readLedgerStats({
    required String ledgerId,
  }) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/ledgers/$ledgerId/stats',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Read ledger stats failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return BeeCountCloudLedgerStats.fromJson(payload);
  }

  /// 拉 server 公开 /version。绕开 auth token —— 登录页未登录状态下也该能
  /// 显示 server 版本,不需要 token。
  Future<BeeCountCloudServerVersion> fetchServerVersion() async {
    final uri = Uri.parse('$baseUrl$apiPrefix/version');
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Fetch version failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return BeeCountCloudServerVersion.fromJson(payload);
  }

  // ===========================================================================
  // 共享账本(Sprint 2.4)— invites / members / shared-resources HTTP 实现
  // ===========================================================================

  Future<BeeCountCloudInvite> createInvite({
    required String ledgerId,
    required String role,
    required int expiresInHours,
  }) async {
    final response = await _authedRequest(
      method: 'POST',
      path: '/ledgers/$ledgerId/invites',
      body: {'role': role, 'expires_in_hours': expiresInHours},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Create invite failed: ${_extractErrorMessage(response)}');
    }
    return BeeCountCloudInvite.fromJson(_decodeJsonObject(response.body));
  }

  Future<List<BeeCountCloudInvite>> listInvites({required String ledgerId}) async {
    final response = await _authedRequest(
      method: 'GET', path: '/ledgers/$ledgerId/invites',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'List invites failed: ${_extractErrorMessage(response)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return [
      for (final row in decoded)
        if (row is Map<String, dynamic>) BeeCountCloudInvite.fromJson(row),
    ];
  }

  Future<void> revokeInvite({required String ledgerId, required String code}) async {
    final response = await _authedRequest(
      method: 'DELETE', path: '/ledgers/$ledgerId/invites/$code',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Revoke invite failed: ${_extractErrorMessage(response)}');
    }
  }

  Future<BeeCountCloudInvitePreview> previewInvite({required String code}) async {
    final response = await _authedRequest(
      method: 'POST', path: '/invites/$code/preview',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Preview invite failed: ${_extractErrorMessage(response)}');
    }
    return BeeCountCloudInvitePreview.fromJson(_decodeJsonObject(response.body));
  }

  Future<BeeCountCloudInviteAcceptResult> acceptInvite({required String code}) async {
    final response = await _authedRequest(
      method: 'POST', path: '/invites/$code/accept',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Accept invite failed: ${_extractErrorMessage(response)}');
    }
    return BeeCountCloudInviteAcceptResult.fromJson(_decodeJsonObject(response.body));
  }

  Future<List<BeeCountCloudLedgerMember>> listMembers({required String ledgerId}) async {
    final response = await _authedRequest(
      method: 'GET', path: '/ledgers/$ledgerId/members',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'List members failed: ${_extractErrorMessage(response)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return [
      for (final row in decoded)
        if (row is Map<String, dynamic>) BeeCountCloudLedgerMember.fromJson(row),
    ];
  }

  Future<BeeCountCloudLedgerMember> updateMemberRole({
    required String ledgerId,
    required String userId,
    required String role,
  }) async {
    final response = await _authedRequest(
      method: 'PATCH',
      path: '/ledgers/$ledgerId/members/$userId',
      body: {'role': role},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Update member role failed: ${_extractErrorMessage(response)}');
    }
    return BeeCountCloudLedgerMember.fromJson(_decodeJsonObject(response.body));
  }

  Future<void> removeMember({required String ledgerId, required String userId}) async {
    final response = await _authedRequest(
      method: 'DELETE', path: '/ledgers/$ledgerId/members/$userId',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Remove member failed: ${_extractErrorMessage(response)}');
    }
  }

  /// 拉 Owner 的 user-global 资源快照(§7 决策 — Editor 端 picker 用)。
  Future<BeeCountCloudSharedResources> fetchSharedResources({required String ledgerId}) async {
    final response = await _authedRequest(
      method: 'GET', path: '/ledgers/$ledgerId/shared-resources',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Fetch shared resources failed: ${_extractErrorMessage(response)}');
    }
    return BeeCountCloudSharedResources.fromJson(_decodeJsonObject(response.body));
  }

  /// 共享账本成员收支统计:server `/ledgers/{id}/member-stats`。
  /// scope: month / year / all;period 可选(YYYY-MM 或 YYYY)。
  Future<BeeCountCloudMemberStats> fetchMemberStats({
    required String ledgerId,
    String scope = 'month',
    String? period,
    int? tzOffsetMinutes,
  }) async {
    final qp = <String, String>{
      'scope': scope,
      if (period != null && period.isNotEmpty) 'period': period,
      if (tzOffsetMinutes != null) 'tz_offset_minutes': '$tzOffsetMinutes',
    };
    final response = await _authedRequest(
      method: 'GET',
      path: '/ledgers/$ledgerId/member-stats',
      query: qp,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Fetch member stats failed: ${_extractErrorMessage(response)}');
    }
    return BeeCountCloudMemberStats.fromJson(_decodeJsonObject(response.body));
  }

  Future<List<BeeCountCloudReadTransaction>> readTransactions({
    required String ledgerId,
    String? txType,
    String? query,
    DateTime? startAt,
    DateTime? endAt,
    int limit = 200,
    int offset = 0,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (txType != null && txType.trim().isNotEmpty) 'tx_type': txType.trim(),
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (startAt != null) 'start_at': startAt.toUtc().toIso8601String(),
      if (endAt != null) 'end_at': endAt.toUtc().toIso8601String(),
    };
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/ledgers/$ledgerId/transactions',
      query: qp,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Read transactions failed: ${_extractErrorMessage(response)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final out = <BeeCountCloudReadTransaction>[];
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) continue;
      out.add(
        BeeCountCloudReadTransaction.fromJson(
          _copyWithNormalizedUrl(row, 'created_by_avatar_url'),
        ),
      );
    }
    return out;
  }

  Future<List<BeeCountCloudReadAccount>> readAccounts({
    required String ledgerId,
  }) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/ledgers/$ledgerId/accounts',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Read accounts failed: ${_extractErrorMessage(response)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final out = <BeeCountCloudReadAccount>[];
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) continue;
      out.add(BeeCountCloudReadAccount.fromJson(row));
    }
    return out;
  }

  Future<List<BeeCountCloudReadCategory>> readCategories({
    required String ledgerId,
  }) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/ledgers/$ledgerId/categories',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Read categories failed: ${_extractErrorMessage(response)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final out = <BeeCountCloudReadCategory>[];
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) continue;
      out.add(BeeCountCloudReadCategory.fromJson(row));
    }
    return out;
  }

  Future<List<BeeCountCloudReadTag>> readTags({
    required String ledgerId,
  }) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/ledgers/$ledgerId/tags',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Read tags failed: ${_extractErrorMessage(response)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final out = <BeeCountCloudReadTag>[];
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) continue;
      out.add(BeeCountCloudReadTag.fromJson(row));
    }
    return out;
  }

  Future<BeeCountCloudWriteCommitMeta> writeCreateLedger({
    String? ledgerId,
    required String ledgerName,
    String currency = 'CNY',
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'ledger_name': ledgerName,
      'currency': currency,
      if (ledgerId != null && ledgerId.trim().isNotEmpty)
        'ledger_id': ledgerId.trim(),
    };
    return _writeRequest(
      method: 'POST',
      path: '/write/ledgers',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeLedgerMeta({
    required String ledgerId,
    required int baseChangeId,
    String? ledgerName,
    String? currency,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (ledgerName != null && ledgerName.trim().isNotEmpty)
        'ledger_name': ledgerName.trim(),
      if (currency != null && currency.trim().isNotEmpty)
        'currency': currency.trim(),
    };
    return _writeRequest(
      method: 'PATCH',
      path: '/write/ledgers/$ledgerId/meta',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeCreateTransaction({
    required String ledgerId,
    required int baseChangeId,
    required String txType,
    required double amount,
    required DateTime happenedAt,
    String? note,
    String? categoryName,
    String? categoryKind,
    String? accountName,
    String? fromAccountName,
    String? toAccountName,
    String? categoryId,
    String? accountId,
    String? fromAccountId,
    String? toAccountId,
    Object? tags,
    List<String>? tagIds,
    List<Map<String, dynamic>>? attachments,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      'tx_type': txType,
      'amount': amount,
      'happened_at': happenedAt.toUtc().toIso8601String(),
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (note != null) 'note': note,
      if (categoryName != null) 'category_name': categoryName,
      if (categoryKind != null) 'category_kind': categoryKind,
      if (accountName != null) 'account_name': accountName,
      if (fromAccountName != null) 'from_account_name': fromAccountName,
      if (toAccountName != null) 'to_account_name': toAccountName,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (fromAccountId != null) 'from_account_id': fromAccountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (tags != null) 'tags': tags,
      if (tagIds != null) 'tag_ids': tagIds,
      if (attachments != null) 'attachments': attachments,
    };
    return _writeRequest(
      method: 'POST',
      path: '/write/ledgers/$ledgerId/transactions',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeUpdateTransaction({
    required String ledgerId,
    required String txId,
    required int baseChangeId,
    String? txType,
    double? amount,
    DateTime? happenedAt,
    String? note,
    String? categoryName,
    String? categoryKind,
    String? accountName,
    String? fromAccountName,
    String? toAccountName,
    String? categoryId,
    String? accountId,
    String? fromAccountId,
    String? toAccountId,
    Object? tags,
    List<String>? tagIds,
    List<Map<String, dynamic>>? attachments,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (txType != null) 'tx_type': txType,
      if (amount != null) 'amount': amount,
      if (happenedAt != null)
        'happened_at': happenedAt.toUtc().toIso8601String(),
      if (note != null) 'note': note,
      if (categoryName != null) 'category_name': categoryName,
      if (categoryKind != null) 'category_kind': categoryKind,
      if (accountName != null) 'account_name': accountName,
      if (fromAccountName != null) 'from_account_name': fromAccountName,
      if (toAccountName != null) 'to_account_name': toAccountName,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (fromAccountId != null) 'from_account_id': fromAccountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (tags != null) 'tags': tags,
      if (tagIds != null) 'tag_ids': tagIds,
      if (attachments != null) 'attachments': attachments,
    };
    return _writeRequest(
      method: 'PATCH',
      path: '/write/ledgers/$ledgerId/transactions/$txId',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeDeleteTransaction({
    required String ledgerId,
    required String txId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
    };
    return _writeRequest(
      method: 'DELETE',
      path: '/write/ledgers/$ledgerId/transactions/$txId',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeCreateAccount({
    required String ledgerId,
    required int baseChangeId,
    required String name,
    String? accountType,
    String? currency,
    double? initialBalance,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      'name': name,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (accountType != null) 'account_type': accountType,
      if (currency != null) 'currency': currency,
      if (initialBalance != null) 'initial_balance': initialBalance,
    };
    return _writeRequest(
      method: 'POST',
      path: '/write/ledgers/$ledgerId/accounts',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeUpdateAccount({
    required String ledgerId,
    required String accountId,
    required int baseChangeId,
    String? name,
    String? accountType,
    String? currency,
    double? initialBalance,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (name != null) 'name': name,
      if (accountType != null) 'account_type': accountType,
      if (currency != null) 'currency': currency,
      if (initialBalance != null) 'initial_balance': initialBalance,
    };
    return _writeRequest(
      method: 'PATCH',
      path: '/write/ledgers/$ledgerId/accounts/$accountId',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeDeleteAccount({
    required String ledgerId,
    required String accountId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
    };
    return _writeRequest(
      method: 'DELETE',
      path: '/write/ledgers/$ledgerId/accounts/$accountId',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeCreateCategory({
    required String ledgerId,
    required int baseChangeId,
    required String name,
    required String kind,
    int? level,
    int? sortOrder,
    String? icon,
    String? iconType,
    String? customIconPath,
    String? iconCloudFileId,
    String? iconCloudSha256,
    String? parentName,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      'name': name,
      'kind': kind,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (level != null) 'level': level,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (icon != null) 'icon': icon,
      if (iconType != null) 'icon_type': iconType,
      if (customIconPath != null) 'custom_icon_path': customIconPath,
      if (iconCloudFileId != null) 'icon_cloud_file_id': iconCloudFileId,
      if (iconCloudSha256 != null) 'icon_cloud_sha256': iconCloudSha256,
      if (parentName != null) 'parent_name': parentName,
    };
    return _writeRequest(
      method: 'POST',
      path: '/write/ledgers/$ledgerId/categories',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeUpdateCategory({
    required String ledgerId,
    required String categoryId,
    required int baseChangeId,
    String? name,
    String? kind,
    int? level,
    int? sortOrder,
    String? icon,
    String? iconType,
    String? customIconPath,
    String? iconCloudFileId,
    String? iconCloudSha256,
    String? parentName,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (level != null) 'level': level,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (icon != null) 'icon': icon,
      if (iconType != null) 'icon_type': iconType,
      if (customIconPath != null) 'custom_icon_path': customIconPath,
      if (iconCloudFileId != null) 'icon_cloud_file_id': iconCloudFileId,
      if (iconCloudSha256 != null) 'icon_cloud_sha256': iconCloudSha256,
      if (parentName != null) 'parent_name': parentName,
    };
    return _writeRequest(
      method: 'PATCH',
      path: '/write/ledgers/$ledgerId/categories/$categoryId',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeDeleteCategory({
    required String ledgerId,
    required String categoryId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
    };
    return _writeRequest(
      method: 'DELETE',
      path: '/write/ledgers/$ledgerId/categories/$categoryId',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeCreateTag({
    required String ledgerId,
    required int baseChangeId,
    required String name,
    String? color,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      'name': name,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (color != null) 'color': color,
    };
    return _writeRequest(
      method: 'POST',
      path: '/write/ledgers/$ledgerId/tags',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeUpdateTag({
    required String ledgerId,
    required String tagId,
    required int baseChangeId,
    String? name,
    String? color,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (name != null) 'name': name,
      if (color != null) 'color': color,
    };
    return _writeRequest(
      method: 'PATCH',
      path: '/write/ledgers/$ledgerId/tags/$tagId',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> writeDeleteTag({
    required String ledgerId,
    required String tagId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
    };
    return _writeRequest(
      method: 'DELETE',
      path: '/write/ledgers/$ledgerId/tags/$tagId',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<BeeCountCloudWriteCommitMeta> _writeRequest({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    String? idempotencyKey,
  }) async {
    final headers = <String, String>{};
    if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey.trim();
    }
    final response = await _authedRequest(
      method: method,
      path: path,
      body: body,
      headers: headers.isEmpty ? null : headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Write request failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return BeeCountCloudWriteCommitMeta.fromJson(payload);
  }

  String _ledgerIdFromPath(String path) {
    final normalized = PathHelper.normalize(path);
    if (normalized.isEmpty) {
      throw CloudStorageException('Invalid path: path is empty');
    }
    return PathHelper.basename(normalized);
  }

  String _cursorStorageKey() {
    final userId = auth.currentUserId ?? 'unknown';
    final deviceId = auth.currentDeviceId ?? 'unknown';
    final raw = '$baseUrl|$apiPrefix|$userId|$deviceId';
    final digest = sha1.convert(utf8.encode(raw)).toString();
    return 'beecount_cloud_pull_cursor_$digest';
  }

  Future<int> _loadCursor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cursorStorageKey()) ?? 0;
  }

  Future<void> _saveCursor(int cursor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cursorStorageKey(), cursor);
  }

  Future<http.Response> _authedRequest({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    var token = await auth.requireAccessToken();
    var response = await _request(
      method: method,
      path: path,
      query: query,
      body: body,
      headers: headers,
      token: token,
    );

    if (response.statusCode == 401) {
      final refreshed = await auth.tryRefreshSession();
      if (!refreshed) {
        throw CloudNotAuthenticatedException(
            'Session expired, please login again.');
      }
      token = await auth.requireAccessToken();
      response = await _request(
        method: method,
        path: path,
        query: query,
        body: body,
        headers: headers,
        token: token,
      );
    }

    return response;
  }

  Future<http.Response> _request({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl$apiPrefix$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final request = http.Request(method, uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = 'application/json';
    if (headers != null && headers.isNotEmpty) {
      request.headers.addAll(headers);
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final streamed = await _httpClient.send(request);
    return http.Response.fromStream(streamed);
  }

  Future<http.Response> _multipartRequest({
    required String ledgerId,
    required Uint8List bytes,
    required String fileName,
    required String token,
    String? mimeType,
  }) async {
    final uri = Uri.parse('$baseUrl$apiPrefix/attachments/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['ledger_id'] = ledgerId;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );
    if (mimeType != null && mimeType.trim().isNotEmpty) {
      request.fields['mime_type'] = mimeType.trim();
    }
    final streamed = await _httpClient.send(request);
    return http.Response.fromStream(streamed);
  }

  /// 分类图标上传的 multipart 请求。跟 [_multipartRequest] 的差别:
  /// 走 `/attachments/category-icons/upload`,不传 ledger_id form 字段。
  Future<http.Response> _categoryIconMultipartRequest({
    required Uint8List bytes,
    required String fileName,
    required String token,
    String? mimeType,
  }) async {
    final uri = Uri.parse('$baseUrl$apiPrefix/attachments/category-icons/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );
    if (mimeType != null && mimeType.trim().isNotEmpty) {
      request.fields['mime_type'] = mimeType.trim();
    }
    final streamed = await _httpClient.send(request);
    return http.Response.fromStream(streamed);
  }

  Future<http.Response> _profileAvatarMultipartRequest({
    required Uint8List bytes,
    required String fileName,
    required String token,
    String? mimeType,
  }) async {
    final uri = Uri.parse('$baseUrl$apiPrefix/profile/avatar');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );
    if (mimeType != null && mimeType.trim().isNotEmpty) {
      request.fields['mime_type'] = mimeType.trim();
    }
    final streamed = await _httpClient.send(request);
    return http.Response.fromStream(streamed);
  }
}

class _BeeCountCloudSession {
  const _BeeCountCloudSession({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.deviceId,
  });

  final String userId;
  final String? email;
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final String deviceId;

  factory _BeeCountCloudSession.fromAuthResponse(Map<String, dynamic> payload) {
    final user = payload['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('Invalid auth response: user missing');
    }

    final userId = user['id'];
    final accessToken = payload['access_token'];
    final refreshToken = payload['refresh_token'];
    final expiresIn = payload['expires_in'];
    final deviceId = payload['device_id'];

    if (userId is! String ||
        accessToken is! String ||
        refreshToken is! String ||
        expiresIn is! num ||
        deviceId is! String) {
      throw const FormatException('Invalid auth response payload');
    }

    return _BeeCountCloudSession(
      userId: userId,
      email: user['email'] as String?,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt:
          DateTime.now().toUtc().add(Duration(seconds: expiresIn.toInt())),
      deviceId: deviceId,
    );
  }

  factory _BeeCountCloudSession.fromJson(Map<String, dynamic> json) {
    return _BeeCountCloudSession(
      userId: json['userId'] as String,
      email: json['email'] as String?,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      accessTokenExpiresAt:
          DateTime.parse(json['accessTokenExpiresAt'] as String).toUtc(),
      deviceId: json['deviceId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
      'deviceId': deviceId,
    };
  }
}

class BeeCountCloudSyncChange {
  const BeeCountCloudSyncChange({
    required this.changeId,
    required this.ledgerId,
    required this.entityType,
    required this.entitySyncId,
    required this.action,
    this.updatedByDeviceId,
    this.updatedAt,
    this.payload,
  });

  final int changeId;
  final String ledgerId;
  final String entityType;
  final String entitySyncId;
  final String action;
  final String? updatedByDeviceId;
  final String? updatedAt;
  final Map<String, dynamic>? payload;
}

class BeeCountCloudPullResult {
  const BeeCountCloudPullResult({
    required this.changes,
    required this.serverCursor,
    required this.hasMore,
  });

  final List<BeeCountCloudSyncChange> changes;
  final int serverCursor;
  final bool hasMore;
}

class BeeCountCloudAttachmentExistsItem {
  const BeeCountCloudAttachmentExistsItem({
    required this.sha256,
    required this.exists,
    this.fileId,
    this.size,
    this.mimeType,
  });

  final String sha256;
  final bool exists;
  final String? fileId;
  final int? size;
  final String? mimeType;

  factory BeeCountCloudAttachmentExistsItem.fromJson(
      Map<String, dynamic> json) {
    return BeeCountCloudAttachmentExistsItem(
      sha256: (json['sha256'] as String?)?.toLowerCase() ?? '',
      exists: json['exists'] == true,
      fileId: json['file_id'] as String?,
      size: (json['size'] as num?)?.toInt(),
      mimeType: json['mime_type'] as String?,
    );
  }
}

class BeeCountCloudAttachmentUploadResult {
  const BeeCountCloudAttachmentUploadResult({
    required this.fileId,
    required this.ledgerId,
    required this.sha256,
    required this.size,
    this.mimeType,
    this.fileName,
  });

  final String fileId;
  final String ledgerId;
  final String sha256;
  final int size;
  final String? mimeType;
  final String? fileName;

  factory BeeCountCloudAttachmentUploadResult.fromJson(
      Map<String, dynamic> json) {
    final fileId = json['file_id'];
    final ledgerId = json['ledger_id'];
    final sha = json['sha256'];
    if (fileId is! String || ledgerId is! String || sha is! String) {
      throw const FormatException('Invalid attachment upload response payload');
    }
    return BeeCountCloudAttachmentUploadResult(
      fileId: fileId,
      ledgerId: ledgerId,
      sha256: sha.toLowerCase(),
      size: (json['size'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String?,
      fileName: json['file_name'] as String?,
    );
  }
}

class BeeCountCloudDevice {
  const BeeCountCloudDevice({
    required this.id,
    required this.name,
    required this.platform,
    this.appVersion,
    this.osVersion,
    this.deviceModel,
    this.lastIp,
    this.lastSeenAt,
    this.createdAt,
    this.sessionCount = 1,
  });

  final String id;
  final String name;
  final String platform;
  final String? appVersion;
  final String? osVersion;
  final String? deviceModel;
  final String? lastIp;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final int sessionCount;

  factory BeeCountCloudDevice.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      appVersion: _trimOrNull(json['app_version'] as String?),
      osVersion: _trimOrNull(json['os_version'] as String?),
      deviceModel: _trimOrNull(json['device_model'] as String?),
      lastIp: _trimOrNull(json['last_ip'] as String?),
      lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      sessionCount: (json['session_count'] as num?)?.toInt() ?? 1,
    );
  }
}

class BeeCountCloudReadLedger {
  const BeeCountCloudReadLedger({
    required this.ledgerId,
    required this.ledgerName,
    required this.currency,
    required this.transactionCount,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.balance,
    required this.role,
    this.isShared = false,
    this.memberCount = 1,
    this.exportedAt,
    this.updatedAt,
  });

  final String ledgerId;
  final String ledgerName;
  final String currency;
  final int transactionCount;
  final double incomeTotal;
  final double expenseTotal;
  final double balance;
  final String role;
  final bool isShared;
  final int memberCount;
  final DateTime? exportedAt;
  final DateTime? updatedAt;

  factory BeeCountCloudReadLedger.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudReadLedger(
      ledgerId: json['ledger_id'] as String? ?? '',
      ledgerName: json['ledger_name'] as String? ?? '',
      currency: json['currency'] as String? ?? 'CNY',
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      incomeTotal: (json['income_total'] as num?)?.toDouble() ?? 0,
      expenseTotal: (json['expense_total'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      role: json['role'] as String? ?? 'viewer',
      isShared: json['is_shared'] as bool? ?? false,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 1,
      exportedAt: DateTime.tryParse(json['exported_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

class BeeCountCloudServerVersion {
  const BeeCountCloudServerVersion({
    required this.name,
    required this.version,
  });

  final String name;
  final String version;

  factory BeeCountCloudServerVersion.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudServerVersion(
      name: (json['name'] as String?)?.trim() ?? 'BeeCount Cloud',
      version: (json['version'] as String?)?.trim() ?? '',
    );
  }
}

class BeeCountCloudLedgerStats {
  const BeeCountCloudLedgerStats({
    required this.transactionCount,
    required this.transactionTotal,
    required this.attachmentCount,
    required this.attachmentTotal,
    required this.categoryAttachmentTotal,
    required this.budgetCount,
    required this.budgetTotal,
    required this.accountCount,
    required this.accountTotal,
    required this.categoryCount,
    required this.categoryTotal,
    required this.tagCount,
    required this.tagTotal,
  });

  /// `*Count`:当前账本口径。`*Total`:当前用户全量账本合计。
  /// user-level 实体(account/category/tag)两者同值,tx/attachment/budget 则
  /// 一般 total 比 count 大。Server 没返 total 字段时(老版本兼容)回退到 count。
  ///
  /// `attachmentCount` / `attachmentTotal` 现在只统计交易附件(server
  /// attachment_kind='transaction')。`categoryAttachmentTotal` 是分类自定
  /// 义图标的全量(user-global,不分账本),老版本 server 没返这个字段时回退到 0。
  final int transactionCount;
  final int transactionTotal;
  final int attachmentCount;
  final int attachmentTotal;
  final int categoryAttachmentTotal;
  final int budgetCount;
  final int budgetTotal;
  final int accountCount;
  final int accountTotal;
  final int categoryCount;
  final int categoryTotal;
  final int tagCount;
  final int tagTotal;

  factory BeeCountCloudLedgerStats.fromJson(Map<String, dynamic> json) {
    int readCount(String key) => (json[key] as num?)?.toInt() ?? 0;
    int readTotalOrFallback(String totalKey, String countKey) {
      final v = (json[totalKey] as num?)?.toInt();
      if (v != null) return v;
      return readCount(countKey);
    }
    return BeeCountCloudLedgerStats(
      transactionCount: readCount('transaction_count'),
      transactionTotal: readTotalOrFallback('transaction_total', 'transaction_count'),
      attachmentCount: readCount('attachment_count'),
      attachmentTotal: readTotalOrFallback('attachment_total', 'attachment_count'),
      categoryAttachmentTotal: readCount('category_attachment_total'),
      budgetCount: readCount('budget_count'),
      budgetTotal: readTotalOrFallback('budget_total', 'budget_count'),
      accountCount: readCount('account_count'),
      accountTotal: readTotalOrFallback('account_total', 'account_count'),
      categoryCount: readCount('category_count'),
      categoryTotal: readTotalOrFallback('category_total', 'category_count'),
      tagCount: readCount('tag_count'),
      tagTotal: readTotalOrFallback('tag_total', 'tag_count'),
    );
  }
}

class BeeCountCloudReadLedgerDetail extends BeeCountCloudReadLedger {
  const BeeCountCloudReadLedgerDetail({
    required super.ledgerId,
    required super.ledgerName,
    required super.currency,
    required super.transactionCount,
    required super.incomeTotal,
    required super.expenseTotal,
    required super.balance,
    required super.role,
    required super.isShared,
    required super.memberCount,
    required this.sourceChangeId,
    super.exportedAt,
    super.updatedAt,
  });

  final int sourceChangeId;

  factory BeeCountCloudReadLedgerDetail.fromJson(Map<String, dynamic> json) {
    final base = BeeCountCloudReadLedger.fromJson(json);
    return BeeCountCloudReadLedgerDetail(
      ledgerId: base.ledgerId,
      ledgerName: base.ledgerName,
      currency: base.currency,
      transactionCount: base.transactionCount,
      incomeTotal: base.incomeTotal,
      expenseTotal: base.expenseTotal,
      balance: base.balance,
      role: base.role,
      isShared: base.isShared,
      memberCount: base.memberCount,
      exportedAt: base.exportedAt,
      updatedAt: base.updatedAt,
      sourceChangeId: (json['source_change_id'] as num?)?.toInt() ?? 0,
    );
  }
}

class BeeCountCloudReadTransaction {
  const BeeCountCloudReadTransaction({
    required this.id,
    required this.txIndex,
    required this.txType,
    required this.amount,
    required this.happenedAt,
    required this.lastChangeId,
    this.note,
    this.categoryName,
    this.categoryKind,
    this.accountName,
    this.fromAccountName,
    this.toAccountName,
    this.categoryId,
    this.accountId,
    this.fromAccountId,
    this.toAccountId,
    this.tags,
    this.tagsList = const [],
    this.tagIds = const [],
    this.attachments,
    this.ledgerId,
    this.ledgerName,
    this.createdByUserId,
    this.createdByEmail,
    this.createdByDisplayName,
    this.createdByAvatarUrl,
    this.createdByAvatarVersion,
  });

  final String id;
  final int txIndex;
  final String txType;
  final double amount;
  final DateTime? happenedAt;
  final String? note;
  final String? categoryName;
  final String? categoryKind;
  final String? accountName;
  final String? fromAccountName;
  final String? toAccountName;
  final String? categoryId;
  final String? accountId;
  final String? fromAccountId;
  final String? toAccountId;
  final String? tags;
  final List<String> tagsList;
  final List<String> tagIds;
  final List<Map<String, dynamic>>? attachments;
  final int lastChangeId;
  final String? ledgerId;
  final String? ledgerName;
  final String? createdByUserId;
  final String? createdByEmail;
  final String? createdByDisplayName;
  final String? createdByAvatarUrl;
  final int? createdByAvatarVersion;

  factory BeeCountCloudReadTransaction.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>>? attachments;
    final attachmentsRaw = json['attachments'];
    if (attachmentsRaw is List) {
      attachments = attachmentsRaw
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList(growable: false);
    }
    return BeeCountCloudReadTransaction(
      id: json['id'] as String? ?? '',
      txIndex: (json['tx_index'] as num?)?.toInt() ?? 0,
      txType: json['tx_type'] as String? ?? 'expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      happenedAt: DateTime.tryParse(json['happened_at'] as String? ?? ''),
      note: json['note'] as String?,
      categoryName: json['category_name'] as String?,
      categoryKind: json['category_kind'] as String?,
      accountName: json['account_name'] as String?,
      fromAccountName: json['from_account_name'] as String?,
      toAccountName: json['to_account_name'] as String?,
      categoryId: json['category_id'] as String?,
      accountId: json['account_id'] as String?,
      fromAccountId: json['from_account_id'] as String?,
      toAccountId: json['to_account_id'] as String?,
      tags: json['tags'] as String?,
      tagsList: _toStringList(json['tags_list']),
      tagIds: _toStringList(json['tag_ids']),
      attachments: attachments,
      lastChangeId: (json['last_change_id'] as num?)?.toInt() ?? 0,
      ledgerId: json['ledger_id'] as String?,
      ledgerName: json['ledger_name'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      createdByEmail: json['created_by_email'] as String?,
      createdByDisplayName:
          _trimOrNull(json['created_by_display_name'] as String?),
      createdByAvatarUrl: _trimOrNull(json['created_by_avatar_url'] as String?),
      createdByAvatarVersion:
          (json['created_by_avatar_version'] as num?)?.toInt(),
    );
  }
}

class BeeCountCloudProfile {
  const BeeCountCloudProfile({
    required this.userId,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.avatarVersion = 0,
    this.incomeIsRed,
    this.themePrimaryColor,
    this.appearance,
    this.aiConfig,
  });

  final String userId;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final int avatarVersion;
  final bool? incomeIsRed;
  final String? themePrimaryColor;
  /// 外观类设置(header_decoration_style / compact_amount /
  /// show_transaction_time …)的 dict,跨设备同步的 user-level JSON。
  final Map<String, dynamic>? appearance;
  /// AI 配置(providers / binding / custom_prompt / strategy …)的 dict。
  final Map<String, dynamic>? aiConfig;

  factory BeeCountCloudProfile.fromJson(Map<String, dynamic> json) {
    final appearanceRaw = json['appearance'];
    final aiConfigRaw = json['ai_config'];
    return BeeCountCloudProfile(
      userId: json['user_id'] as String? ?? '',
      email: _trimOrNull(json['email'] as String?),
      displayName: _trimOrNull(json['display_name'] as String?),
      avatarUrl: _trimOrNull(json['avatar_url'] as String?),
      avatarVersion: (json['avatar_version'] as num?)?.toInt() ?? 0,
      incomeIsRed: json['income_is_red'] as bool?,
      themePrimaryColor: _trimOrNull(json['theme_primary_color'] as String?),
      appearance: appearanceRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(appearanceRaw)
          : null,
      aiConfig: aiConfigRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(aiConfigRaw)
          : null,
    );
  }
}

class BeeCountCloudAvatarUploadResult {
  const BeeCountCloudAvatarUploadResult({
    this.avatarUrl,
    this.avatarVersion = 0,
  });

  final String? avatarUrl;
  final int avatarVersion;

  factory BeeCountCloudAvatarUploadResult.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudAvatarUploadResult(
      avatarUrl: _trimOrNull(json['avatar_url'] as String?),
      avatarVersion: (json['avatar_version'] as num?)?.toInt() ?? 0,
    );
  }
}

class BeeCountCloudReadAccount {
  const BeeCountCloudReadAccount({
    required this.id,
    required this.name,
    required this.lastChangeId,
    this.accountType,
    this.currency,
    this.initialBalance,
    this.ledgerId,
    this.ledgerName,
    this.createdByUserId,
    this.createdByEmail,
  });

  final String id;
  final String name;
  final String? accountType;
  final String? currency;
  final double? initialBalance;
  final int lastChangeId;
  final String? ledgerId;
  final String? ledgerName;
  final String? createdByUserId;
  final String? createdByEmail;

  factory BeeCountCloudReadAccount.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudReadAccount(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      accountType: json['account_type'] as String?,
      currency: json['currency'] as String?,
      initialBalance: (json['initial_balance'] as num?)?.toDouble(),
      lastChangeId: (json['last_change_id'] as num?)?.toInt() ?? 0,
      ledgerId: json['ledger_id'] as String?,
      ledgerName: json['ledger_name'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      createdByEmail: json['created_by_email'] as String?,
    );
  }
}

class BeeCountCloudReadCategory {
  const BeeCountCloudReadCategory({
    required this.id,
    required this.name,
    required this.kind,
    required this.lastChangeId,
    this.level,
    this.sortOrder,
    this.icon,
    this.iconType,
    this.customIconPath,
    this.iconCloudFileId,
    this.iconCloudSha256,
    this.parentName,
    this.ledgerId,
    this.ledgerName,
    this.createdByUserId,
    this.createdByEmail,
  });

  final String id;
  final String name;
  final String kind;
  final int? level;
  final int? sortOrder;
  final String? icon;
  final String? iconType;
  final String? customIconPath;
  final String? iconCloudFileId;
  final String? iconCloudSha256;
  final String? parentName;
  final int lastChangeId;
  final String? ledgerId;
  final String? ledgerName;
  final String? createdByUserId;
  final String? createdByEmail;

  factory BeeCountCloudReadCategory.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudReadCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'expense',
      level: (json['level'] as num?)?.toInt(),
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      icon: json['icon'] as String?,
      iconType: json['icon_type'] as String?,
      customIconPath: json['custom_icon_path'] as String?,
      iconCloudFileId: json['icon_cloud_file_id'] as String?,
      iconCloudSha256: json['icon_cloud_sha256'] as String?,
      parentName: json['parent_name'] as String?,
      lastChangeId: (json['last_change_id'] as num?)?.toInt() ?? 0,
      ledgerId: json['ledger_id'] as String?,
      ledgerName: json['ledger_name'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      createdByEmail: json['created_by_email'] as String?,
    );
  }
}

class BeeCountCloudReadTag {
  const BeeCountCloudReadTag({
    required this.id,
    required this.name,
    required this.lastChangeId,
    this.color,
    this.ledgerId,
    this.ledgerName,
    this.createdByUserId,
    this.createdByEmail,
  });

  final String id;
  final String name;
  final String? color;
  final int lastChangeId;
  final String? ledgerId;
  final String? ledgerName;
  final String? createdByUserId;
  final String? createdByEmail;

  factory BeeCountCloudReadTag.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudReadTag(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: json['color'] as String?,
      lastChangeId: (json['last_change_id'] as num?)?.toInt() ?? 0,
      ledgerId: json['ledger_id'] as String?,
      ledgerName: json['ledger_name'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      createdByEmail: json['created_by_email'] as String?,
    );
  }
}

class BeeCountCloudWriteCommitMeta {
  const BeeCountCloudWriteCommitMeta({
    required this.ledgerId,
    required this.baseChangeId,
    required this.newChangeId,
    required this.serverTimestamp,
    required this.idempotencyReplayed,
    this.entityId,
  });

  final String ledgerId;
  final int baseChangeId;
  final int newChangeId;
  final DateTime? serverTimestamp;
  final bool idempotencyReplayed;
  final String? entityId;

  factory BeeCountCloudWriteCommitMeta.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudWriteCommitMeta(
      ledgerId: json['ledger_id'] as String? ?? '',
      baseChangeId: (json['base_change_id'] as num?)?.toInt() ?? 0,
      newChangeId: (json['new_change_id'] as num?)?.toInt() ?? 0,
      serverTimestamp:
          DateTime.tryParse(json['server_timestamp'] as String? ?? ''),
      idempotencyReplayed: json['idempotency_replayed'] == true,
      entityId: json['entity_id'] as String?,
    );
  }
}

class BeeCountCloudRealtimeEvent {
  const BeeCountCloudRealtimeEvent({
    required this.type,
    this.ledgerId,
    this.serverCursor,
    this.rawData = const <String, dynamic>{},
  });

  final String type;
  final String? ledgerId;
  final int? serverCursor;
  /// 完整 payload(server 推过来的 dict)。新事件类型(member_change /
  /// shared_resource_change)字段从这里读,避免每加一种事件都改 RealtimeEvent
  /// 类。
  final Map<String, dynamic> rawData;
}

class BeeCountCloudRealtimeClient {
  BeeCountCloudRealtimeClient({
    required this.baseUrl,
    required this.auth,
  });

  final String baseUrl;
  final BeeCountCloudAuthService auth;

  final StreamController<BeeCountCloudRealtimeEvent> _events =
      StreamController<BeeCountCloudRealtimeEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _running = false;
  bool _connecting = false;

  Stream<BeeCountCloudRealtimeEvent> get events => _events.stream;

  Future<void> start() async {
    if (_running) {
      return;
    }
    _running = true;
    await _connect();
  }

  Future<void> stop() async {
    _running = false;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer = null;
    await _channelSub?.cancel();
    _channelSub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _events.close();
  }

  Future<void> _connect() async {
    if (!_running || _connecting) {
      return;
    }
    _connecting = true;

    try {
      final token = await auth.requireAccessToken();
      final uri = _buildWebSocketUri(token);
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      _channelSub = channel.stream.listen(
        _onMessage,
        onDone: _scheduleReconnect,
        onError: (_, __) => _scheduleReconnect(),
        cancelOnError: true,
      );

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        try {
          _channel?.sink.add('ping');
        } catch (_) {}
      });

      // 发一条 "connected" 事件给业务层，让 SyncEngine 知道 WS 重连成功 ——
      // 离线累积的 local_changes 可以此时 flush。没有这个通知的话，断网
      // 期间用户改的东西要等下一次交易写入 / PostProcessor.sync() 才推出去。
      _events.add(const BeeCountCloudRealtimeEvent(type: 'connected'));
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  Uri _buildWebSocketUri(String token) {
    final base = Uri.parse(baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final segments = <String>[
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      'ws',
    ];

    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/${segments.join('/')}',
      queryParameters: {'token': token},
    );
  }

  void _onMessage(dynamic message) {
    if (message is! String || message.trim().isEmpty || message == 'pong') {
      return;
    }

    try {
      final payload = jsonDecode(message);
      if (payload is! Map<String, dynamic>) {
        return;
      }
      final type = payload['type'];
      if (type is! String || type.isEmpty) {
        return;
      }
      final serverCursor = (payload['serverCursor'] as num?)?.toInt();
      _events.add(
        BeeCountCloudRealtimeEvent(
          type: type,
          ledgerId: payload['ledgerId'] as String?,
          serverCursor: serverCursor,
          rawData: payload,
        ),
      );
    } catch (_) {}
  }

  void _scheduleReconnect([Object? _, StackTrace? __]) {
    if (!_running) {
      return;
    }

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _channelSub?.cancel();
    _channelSub = null;
    _channel = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (!_running) {
        return;
      }
      await auth.tryRefreshSession();
      await _connect();
    });
  }
}

String _normalizeApiPrefix(String raw) {
  var prefix = raw.trim();
  if (prefix.isEmpty) {
    return '/api/v1';
  }
  if (!prefix.startsWith('/')) {
    prefix = '/$prefix';
  }
  if (prefix.endsWith('/')) {
    prefix = prefix.substring(0, prefix.length - 1);
  }
  return prefix;
}

Map<String, dynamic> _decodeJsonObject(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid JSON response');
  }
  return decoded;
}

List<String> _toStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

String _extractErrorMessage(http.Response response) {
  try {
    final payload = _decodeJsonObject(response.body);
    final detail = payload['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
  } catch (_) {}
  return 'HTTP ${response.statusCode}';
}

// =============================================================================
// 共享账本数据类(Sprint 2.4 — Phase 1)
// =============================================================================

class BeeCountCloudInvite {
  const BeeCountCloudInvite({
    required this.code,
    required this.formattedCode,
    required this.targetRole,
    required this.expiresAt,
    required this.createdAt,
    required this.shareUrl,
    this.invitedByUserId,
  });

  /// 6 位明文邀请码(`ABC123`)。
  final String code;
  /// 显示用 "ABC 123"(中间空格易读)。
  final String formattedCode;
  final String targetRole;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String shareUrl;
  /// list endpoint 返回时带,create 不带(创建者自己即 caller)。
  final String? invitedByUserId;

  factory BeeCountCloudInvite.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudInvite(
      code: (json['code'] as String?)?.trim() ?? '',
      formattedCode: (json['formatted_code'] as String?)?.trim() ?? '',
      targetRole: (json['target_role'] as String?)?.trim() ?? 'editor',
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '')?.toUtc()
          ?? DateTime.now().toUtc(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc()
          ?? DateTime.now().toUtc(),
      shareUrl: (json['share_url'] as String?)?.trim() ?? '',
      invitedByUserId: (json['invited_by_user_id'] as String?)?.trim().isEmpty == true
          ? null
          : json['invited_by_user_id'] as String?,
    );
  }
}

class BeeCountCloudInvitePreview {
  const BeeCountCloudInvitePreview({
    required this.code,
    required this.ledgerExternalId,
    required this.ledgerCurrency,
    required this.invitedByDisplay,
    required this.targetRole,
    required this.expiresAt,
    this.ledgerName,
  });

  final String code;
  final String ledgerExternalId;
  final String? ledgerName;
  final String ledgerCurrency;
  final String invitedByDisplay;
  final String targetRole;
  final DateTime expiresAt;

  factory BeeCountCloudInvitePreview.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudInvitePreview(
      code: (json['code'] as String?)?.trim() ?? '',
      ledgerExternalId: (json['ledger_external_id'] as String?)?.trim() ?? '',
      ledgerName: json['ledger_name'] as String?,
      ledgerCurrency: (json['ledger_currency'] as String?)?.trim() ?? 'CNY',
      invitedByDisplay: (json['invited_by_display'] as String?)?.trim() ?? 'Unknown',
      targetRole: (json['target_role'] as String?)?.trim() ?? 'editor',
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '')?.toUtc()
          ?? DateTime.now().toUtc(),
    );
  }
}

class BeeCountCloudInviteAcceptResult {
  const BeeCountCloudInviteAcceptResult({
    required this.ledgerExternalId,
    required this.ledgerCurrency,
    required this.role,
    required this.memberCount,
    this.ledgerName,
  });

  final String ledgerExternalId;
  final String? ledgerName;
  final String ledgerCurrency;
  final String role;
  final int memberCount;

  factory BeeCountCloudInviteAcceptResult.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudInviteAcceptResult(
      ledgerExternalId: (json['ledger_external_id'] as String?)?.trim() ?? '',
      ledgerName: json['ledger_name'] as String?,
      ledgerCurrency: (json['ledger_currency'] as String?)?.trim() ?? 'CNY',
      role: (json['role'] as String?)?.trim() ?? 'editor',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 1,
    );
  }
}

class BeeCountCloudLedgerMember {
  const BeeCountCloudLedgerMember({
    required this.userId,
    required this.email,
    required this.role,
    required this.joinedAt,
    required this.isSelf,
    this.displayName,
    this.invitedByUserId,
    this.avatarUrl,
    this.avatarVersion = 0,
  });

  final String userId;
  final String email;
  final String? displayName;
  final String role;
  final DateTime joinedAt;
  final String? invitedByUserId;
  final bool isSelf;
  /// server-side relative path,例 "/api/v1/profile/avatar/{uid}?v=N"。null = 用户未上传头像。
  final String? avatarUrl;
  final int avatarVersion;

  factory BeeCountCloudLedgerMember.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudLedgerMember(
      userId: (json['user_id'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim() ?? '',
      displayName: json['display_name'] as String?,
      role: (json['role'] as String?)?.trim() ?? 'editor',
      joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '')?.toUtc()
          ?? DateTime.now().toUtc(),
      invitedByUserId: json['invited_by_user_id'] as String?,
      isSelf: json['is_self'] as bool? ?? false,
      avatarUrl: (json['avatar_url'] as String?)?.trim().isEmpty == true
          ? null
          : json['avatar_url'] as String?,
      avatarVersion: (json['avatar_version'] as num?)?.toInt() ?? 0,
    );
  }
}

/// §7 决策 — Editor 接受邀请后拉到的 Owner user-global 资源快照。
class BeeCountCloudSharedResources {
  const BeeCountCloudSharedResources({
    required this.ownerUserId,
    required this.categories,
    required this.accounts,
    required this.tags,
  });

  final String ownerUserId;
  final List<BeeCountCloudSharedCategory> categories;
  final List<BeeCountCloudSharedAccount> accounts;
  final List<BeeCountCloudSharedTag> tags;

  factory BeeCountCloudSharedResources.fromJson(Map<String, dynamic> json) {
    final cats = json['categories'];
    final accts = json['accounts'];
    final tgs = json['tags'];
    return BeeCountCloudSharedResources(
      ownerUserId: (json['owner_user_id'] as String?)?.trim() ?? '',
      categories: cats is List
          ? [
              for (final c in cats)
                if (c is Map<String, dynamic>)
                  BeeCountCloudSharedCategory.fromJson(c),
            ]
          : const [],
      accounts: accts is List
          ? [
              for (final a in accts)
                if (a is Map<String, dynamic>)
                  BeeCountCloudSharedAccount.fromJson(a),
            ]
          : const [],
      tags: tgs is List
          ? [
              for (final t in tgs)
                if (t is Map<String, dynamic>) BeeCountCloudSharedTag.fromJson(t),
            ]
          : const [],
    );
  }
}

class BeeCountCloudSharedCategory {
  const BeeCountCloudSharedCategory({
    required this.syncId,
    required this.name,
    required this.kind,
    this.icon,
    this.iconType,
    this.iconCloudFileId,
    this.iconCloudSha256,
    this.sortOrder,
    this.level,
    this.parentName,
    this.parentSyncId,
  });

  final String syncId;
  final String name;
  final String kind; // expense / income
  final String? icon;
  final String? iconType; // material / custom / community
  final String? iconCloudFileId;
  final String? iconCloudSha256;
  final int? sortOrder;
  final int? level;
  final String? parentName;
  // 共享账本二级分类:parent 的 syncId,client 端用它建稳定父子链。
  final String? parentSyncId;

  factory BeeCountCloudSharedCategory.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudSharedCategory(
      syncId: (json['sync_id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      kind: (json['kind'] as String?)?.trim() ?? 'expense',
      icon: json['icon'] as String?,
      iconType: json['icon_type'] as String?,
      iconCloudFileId: json['icon_cloud_file_id'] as String?,
      iconCloudSha256: json['icon_cloud_sha256'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      level: (json['level'] as num?)?.toInt(),
      parentName: json['parent_name'] as String?,
      parentSyncId: json['parent_sync_id'] as String?,
    );
  }
}

class BeeCountCloudSharedAccount {
  const BeeCountCloudSharedAccount({
    required this.syncId,
    required this.name,
    this.accountType,
    this.currency,
    this.initialBalance,
    this.note,
    this.creditLimit,
    this.billingDay,
    this.paymentDueDay,
    this.bankName,
    this.cardLastFour,
  });

  final String syncId;
  final String name;
  final String? accountType;
  final String? currency;
  final double? initialBalance;
  final String? note;
  final double? creditLimit;
  final int? billingDay;
  final int? paymentDueDay;
  final String? bankName;
  final String? cardLastFour;

  factory BeeCountCloudSharedAccount.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudSharedAccount(
      syncId: (json['sync_id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      accountType: json['account_type'] as String?,
      currency: json['currency'] as String?,
      initialBalance: (json['initial_balance'] as num?)?.toDouble(),
      note: json['note'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble(),
      billingDay: (json['billing_day'] as num?)?.toInt(),
      paymentDueDay: (json['payment_due_day'] as num?)?.toInt(),
      bankName: json['bank_name'] as String?,
      cardLastFour: json['card_last_four'] as String?,
    );
  }
}

class BeeCountCloudSharedTag {
  const BeeCountCloudSharedTag({
    required this.syncId,
    required this.name,
    this.color,
  });

  final String syncId;
  final String name;
  final String? color;

  factory BeeCountCloudSharedTag.fromJson(Map<String, dynamic> json) {
    return BeeCountCloudSharedTag(
      syncId: (json['sync_id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      color: json['color'] as String?,
    );
  }
}

/// 共享账本成员收支统计单行(对应 server MemberStatItem)。
class BeeCountCloudMemberStatItem {
  const BeeCountCloudMemberStatItem({
    required this.userId,
    required this.role,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.txCount,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.avatarVersion = 0,
  });

  final String userId;
  final String? email;
  final String? displayName;
  /// server-side relative path,例 "/api/v1/profile/avatar/{uid}?v=N"。null = 用户未上传头像。
  final String? avatarUrl;
  final int avatarVersion;
  /// 'owner' / 'editor' / 'removed'(被踢成员但 tx 仍有归属)。
  final String role;
  final double incomeTotal;
  final double expenseTotal;
  final int txCount;

  factory BeeCountCloudMemberStatItem.fromJson(Map<String, dynamic> json) {
    final avatar = (json['avatar_url'] as String?)?.trim();
    return BeeCountCloudMemberStatItem(
      userId: (json['user_id'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim().isEmpty == true
          ? null
          : json['email'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: (avatar == null || avatar.isEmpty) ? null : avatar,
      avatarVersion: (json['avatar_version'] as num?)?.toInt() ?? 0,
      role: (json['role'] as String?)?.trim() ?? 'editor',
      incomeTotal: (json['income_total'] as num?)?.toDouble() ?? 0.0,
      expenseTotal: (json['expense_total'] as num?)?.toDouble() ?? 0.0,
      txCount: (json['tx_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 共享账本成员收支统计响应(对应 server MemberStatsResponse)。
class BeeCountCloudMemberStats {
  const BeeCountCloudMemberStats({
    required this.ledgerId,
    required this.ledgerCurrency,
    required this.scope,
    required this.items,
    this.period,
    this.startAt,
    this.endAt,
  });

  final String ledgerId;
  final String ledgerCurrency;
  /// 'month' / 'year' / 'all'。
  final String scope;
  /// month → "YYYY-MM";year → "YYYY";all → null。
  final String? period;
  final DateTime? startAt;
  final DateTime? endAt;
  final List<BeeCountCloudMemberStatItem> items;

  factory BeeCountCloudMemberStats.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <BeeCountCloudMemberStatItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map<String, dynamic>) {
          items.add(BeeCountCloudMemberStatItem.fromJson(entry));
        }
      }
    }
    DateTime? parseDate(String key) {
      final raw = json[key];
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw)?.toUtc();
      }
      return null;
    }

    return BeeCountCloudMemberStats(
      ledgerId: (json['ledger_id'] as String?)?.trim() ?? '',
      ledgerCurrency: (json['ledger_currency'] as String?)?.trim() ?? 'CNY',
      scope: (json['scope'] as String?)?.trim() ?? 'month',
      period: (json['period'] as String?)?.trim().isEmpty == true
          ? null
          : json['period'] as String?,
      startAt: parseDate('start_at'),
      endAt: parseDate('end_at'),
      items: items,
    );
  }
}
