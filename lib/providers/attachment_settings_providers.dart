import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 默认沿用附件压缩；开启后，新附件保留原图。
class AttachmentKeepOriginalNotifier extends AsyncNotifier<bool> {
  static const preferenceKey = 'attachmentKeepOriginal';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(preferenceKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preferenceKey, enabled);
    state = AsyncData(enabled);
  }
}

final attachmentKeepOriginalProvider =
    AsyncNotifierProvider<AttachmentKeepOriginalNotifier, bool>(
  AttachmentKeepOriginalNotifier.new,
);
