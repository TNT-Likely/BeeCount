import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

// S1-01b-1 锁账提示基础件。
//
// 锁账相关的 toast 文案全部收在这一处,理由有两条:
//   1. 术语统一 —— 全 App 只说「锁账」「锁账日期」,不混用"封存 / 锁定 /
//      归档",否则用户会在设置页、只读提示、批量汇总里看到三套说法;
//   2. tone 语义统一 —— 成功=success、无法操作(如没有可撤销记录)=warning、
//      失败=error。1b-1 单条提示、1b-2 只读态提示、1b-3 批量提示共用同一套。
//
// 这里只做"提示",不做任何状态判断:能不能锁、能不能撤销由调用方判定。

/// 新增锁账成功。
void showLockPeriodCreatedToast(BuildContext context, String lockDate) {
  showBeeToast(
    context,
    AppLocalizations.of(context).lockPeriodCreated(lockDate),
    tone: BeeTone.success,
  );
}

/// 撤销最近一次锁账成功。[effective] 是回退后的当前锁定日;
/// 没有剩余记录时调用方传 "已无锁账" 文案。
void showLockPeriodRevokedToast(BuildContext context, String effective) {
  showBeeToast(
    context,
    AppLocalizations.of(context).lockPeriodRevoked(effective),
    tone: BeeTone.success,
  );
}

/// 写操作失败(统一带上错误详情,便于用户截图反馈)。
void showLockPeriodFailedToast(BuildContext context, Object error) {
  showBeeToast(
    context,
    AppLocalizations.of(context).lockPeriodFailed('$error'),
    tone: BeeTone.error,
  );
}

/// 没有可撤销的锁账记录(不是错误,但要让用户知道为什么没反应)。
void showLockPeriodNothingToRevokeToast(BuildContext context) {
  showBeeToast(
    context,
    AppLocalizations.of(context).lockPeriodNothingToRevoke,
    tone: BeeTone.warning,
  );
}
