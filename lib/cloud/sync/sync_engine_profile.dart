part of 'sync_engine.dart';

/// 用户 profile + avatar 同步。拉 `/profile/me` 把主题色 / 收支配色 / 外观
/// / AI 配置 / 头像都回写到本地。
///
/// `syncMyProfile` 是 public,被外部 sync_providers / 内部 WS 事件调用,
/// 所以 extension 名是 public。
extension SyncEngineProfile on SyncEngine {
  /// 独立调这个而不是夹在 sync() 中间（sync() 前置步骤抛错会 skip 掉这里）。
  /// 返回 true 表示有实际下载并写盘，调用方用来决定要不要 bump 刷新信号。
  /// 拉 /profile/me 并把 theme_primary_color / income_is_red / appearance /
  /// 头像都落回本地(SharedPreferences + 本地文件)。任意字段有更新都返 true,
  /// 让调用方 bump 对应 UI refresh tick。
  ///
  /// 用 [onAppearanceApplied]/[onThemeApplied]/[onIncomeColorApplied] 回调
  /// 让 sync_providers 层把值写进 Riverpod state + SharedPreferences,避免
  /// 这里直接依赖 Riverpod。回调不写就只同步头像(向后兼容)。
  Future<bool> syncMyProfile({
    void Function(String hex)? themeApplied,
    void Function(bool incomeIsRed)? incomeApplied,
    void Function(Map<String, dynamic> appearance)? appearanceApplied,
    void Function(Map<String, dynamic> aiConfig)? aiConfigApplied,
  }) async {
    // 没显式传参数时走 SyncEngine 的全局回调(sync_providers 在构造时注入)。
    // 这样 bootstrap / WS profile_change 两个内部调用点都能自动用到。
    final onThemeApplied = themeApplied ?? onThemeColorApplied;
    final onIncomeApplied = incomeApplied ?? onIncomeColorApplied;
    final onAppearanceCallback = appearanceApplied ?? onAppearanceApplied;
    final onAiConfigCallback = aiConfigApplied ?? onAiConfigApplied;
    final localVersion = await AvatarService.getStoredRemoteVersion();
    logger.info('avatar_sync',
        'syncMyProfile start, localVersion=$localVersion');
    bool anyChanged = false;
    try {
      final profile = await provider.getMyProfile();

      // === theme_primary_color ===
      final theme = profile.themePrimaryColor;
      if (theme != null && theme.isNotEmpty && onThemeApplied != null) {
        try {
          onThemeApplied(theme);
          anyChanged = true;
        } catch (e, st) {
          logger.warning('profile_sync', 'onThemeApplied 失败: $e', st);
        }
      }

      // === income_is_red ===
      final incomeIsRed = profile.incomeIsRed;
      if (incomeIsRed != null && onIncomeApplied != null) {
        try {
          onIncomeApplied(incomeIsRed);
          anyChanged = true;
        } catch (e, st) {
          logger.warning('profile_sync', 'onIncomeApplied 失败: $e', st);
        }
      }

      // === appearance (header_decoration_style / compact_amount / show_transaction_time) ===
      final appearance = profile.appearance;
      if (appearance != null && appearance.isNotEmpty && onAppearanceCallback != null) {
        try {
          onAppearanceCallback(appearance);
          anyChanged = true;
        } catch (e, st) {
          logger.warning('profile_sync', 'onAppearanceCallback 失败: $e', st);
        }
      }

      // === ai_config (providers / binding / custom_prompt / strategy …) ===
      final aiConfig = profile.aiConfig;
      if (aiConfig != null && aiConfig.isNotEmpty && onAiConfigCallback != null) {
        try {
          onAiConfigCallback(aiConfig);
          anyChanged = true;
        } catch (e, st) {
          logger.warning('profile_sync', 'onAiConfigCallback 失败: $e', st);
        }
      }

      // === avatar ===
      final url = profile.avatarUrl;
      final remoteVersion = profile.avatarVersion;
      logger.info('avatar_sync',
          'got profile url=$url remoteVersion=$remoteVersion');
      if (url == null || url.isEmpty) {
        logger.info('avatar_sync', 'server has no avatar, skip download');
        return anyChanged;
      }
      if (remoteVersion > 0 && remoteVersion == localVersion) {
        logger.info('avatar_sync',
            'avatar up-to-date (version=$remoteVersion), skip download');
        return anyChanged;
      }
      // profile 头像专用下载路径。之前这里用正则从 avatar_url 里抠
      // `attachments/(.+)` 的 fileId 然后走 downloadAttachment —— 但服务端
      // 真实 URL 是 `/profile/avatar/<user_id>?v=<v>`，和 attachment 不是
      // 同一套存储，正则永远不命中，于是"初次同步头像"永远失败。
      // 现在直接用 downloadMyAvatar(userId, version) 走对的端点。
      final bytes = await provider.downloadMyAvatar(
        userId: profile.userId,
        version: remoteVersion > 0 ? remoteVersion : null,
      );
      logger.info('avatar_sync', 'downloaded size=${bytes.length}B');
      await AvatarService.saveAvatarFromBytes(bytes);
      await AvatarService.setStoredRemoteVersion(remoteVersion);
      logger.info('avatar_sync',
          'saved to local, bumped localVersion=$remoteVersion');
      // 真下载了头像才触发回调,让外部 bump avatarRefreshProvider。
      // up-to-date / no avatar 分支不触发,避免冷启动一次刷新。
      try {
        onAvatarChanged?.call();
      } catch (e, st) {
        logger.warning('avatar_sync', 'onAvatarChanged 回调失败: $e', st);
      }
      return true;
    } catch (e, st) {
      logger.warning('avatar_sync', '同步失败: $e', st);
      return anyChanged;
    }
  }
}
