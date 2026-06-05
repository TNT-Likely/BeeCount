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
  /// PR 3:不再接 callback,所有字段更新走 [events] stream emit
  /// `ProfileFieldApplied` 事件,UI 通过 syncEventStreamProvider 订阅处理。
  Future<bool> syncMyProfile() async {
    final localVersion = await AvatarService.getStoredRemoteVersion();
    logger.info('avatar_sync',
        'syncMyProfile start, localVersion=$localVersion');
    bool anyChanged = false;
    try {
      final profile = await provider.getMyProfile();

      // === theme_primary_color ===
      final theme = profile.themePrimaryColor;
      if (theme != null && theme.isNotEmpty) {
        _emit(ProfileFieldApplied.themeColor(theme));
        anyChanged = true;
      }

      // === display_name === (v1 只在 server 有值时下行;不下空,故对端不会被清空)
      final displayName = profile.displayName;
      if (displayName != null && displayName.isNotEmpty) {
        _emit(ProfileFieldApplied.displayName(displayName));
        anyChanged = true;
      }

      // === income_is_red ===
      final incomeIsRed = profile.incomeIsRed;
      if (incomeIsRed != null) {
        _emit(ProfileFieldApplied.incomeColor(incomeIsRed));
        anyChanged = true;
      }

      // === appearance (header_decoration_style / compact_amount / show_transaction_time) ===
      final appearance = profile.appearance;
      if (appearance != null && appearance.isNotEmpty) {
        _emit(ProfileFieldApplied.appearance(appearance));
        anyChanged = true;
      }

      // === ai_config (providers / binding / custom_prompt / strategy …) ===
      final aiConfig = profile.aiConfig;
      if (aiConfig != null && aiConfig.isNotEmpty) {
        _emit(ProfileFieldApplied.aiConfig(aiConfig));
        anyChanged = true;
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
      // 真下载了头像才 emit AvatarChanged,让 UI bump avatarRefreshProvider。
      // up-to-date / no avatar 分支不触发,避免冷启动一次刷新。
      _emit(const AvatarChanged());
      return true;
    } catch (e, st) {
      logger.warning('avatar_sync', '同步失败: $e', st);
      return anyChanged;
    }
  }
}
