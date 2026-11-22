/// BeeCount-Cloud 二次开发 REST API 服务层。
///
/// 背景(对接文档 SECONDARY_DEVELOPMENT.md)：
/// 联系人/借款/储蓄罐/报销/物品/定期/公司/消费成员这些实体在 Cloud 端是
/// 「服务端直管表 + REST CRUD」，**不进 mobile sync change log**，仅通过
/// txSyncId 与交易流水关联。因此 App 端必须走 REST 直连，不能靠 sync。
///
/// 本服务复用 BeeCountCloudAuthService.requestSecondaryJson(自动带 Bearer token、
/// 过期自动刷新/静默重登)，把 Cloud 端点封装成强类型 Dart 方法。
///
/// 命名：Cloud snake_case ↔ Dart 用 Map 直出，上层 model 自行转换，
/// 避免在这一层重复定义 8 套 model(后续 UI 可按需加)。
///
/// 返回类型中的 Map 与 List 均为标准 dart:core 集合。
library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

/// 把 REST 返回的 Map 安全转成 Map 列表。
List<Map<String, dynamic>> _asList(dynamic v) {
  if (v == null) return const [];
  if (v is List) {
    return v
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return const [];
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

/// 二次开发 REST 服务。持有 provider 实例(已登录)。
class CloudSecondaryService {
  CloudSecondaryService(this._cloud);

  final BeeCountCloudProvider _cloud;

  BeeCountCloudAuthService get _auth =>
      _cloud.auth as BeeCountCloudAuthService;

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) =>
      _auth.requestSecondaryJson('GET', path, query: query);
  Future<dynamic> _post(String path, [Object? body]) =>
      _auth.requestSecondaryJson('POST', path, body: body);
  Future<dynamic> _patch(String path, Object body) =>
      _auth.requestSecondaryJson('PATCH', path, body: body);
  Future<dynamic> _delete(String path) =>
      _auth.requestSecondaryJson('DELETE', path);

  // ==================== 联系人 (0026/0042/0066) ====================

  /// state: active(默认,未归档含停用) / archived / disabled / all。
  Future<List<Map<String, dynamic>>> listContacts({String state = 'active'}) =>
      _get('/contacts', {'state': state}).then(_asList);

  Future<Map<String, dynamic>> createContact(Map<String, dynamic> body) =>
      _post('/contacts', body).then(_asMap);

  Future<Map<String, dynamic>> updateContact(
          String id, Map<String, dynamic> body) =>
      _patch('/contacts/$id', body).then(_asMap);

  Future<void> deleteContact(String id) => _delete('/contacts/$id');

  /// 4 个幂等状态动作：archive/unarchive/disable/enable。
  Future<void> contactAction(String id, String action) =>
      _post('/contacts/$id/$action');

  Future<Map<String, dynamic>> contactSummary(String id) =>
      _get('/contacts/$id/summary').then(_asMap);

  /// 借款排行默认跨全部账本。
  Future<List<Map<String, dynamic>>> contactLoanRanks() =>
      _get('/contacts/loan-ranks').then(_asList);

  // ==================== 借款 (0026-0033/0039) ====================

  Future<List<Map<String, dynamic>>> listLoans() =>
      _get('/loans').then(_asList);

  Future<Map<String, dynamic>> createLoan(Map<String, dynamic> body) =>
      _post('/loans', body).then(_asMap);

  Future<Map<String, dynamic>> updateLoan(String id, Map<String, dynamic> body) =>
      _patch('/loans/$id', body).then(_asMap);

  Future<void> deleteLoan(String id) => _delete('/loans/$id');

  Future<List<Map<String, dynamic>>> loanRepayments(String loanId) =>
      _get('/loans/$loanId/repayments').then(_asList);

  Future<Map<String, dynamic>> addRepayment(
          String loanId, Map<String, dynamic> body) =>
      _post('/loans/$loanId/repayments', body).then(_asMap);

  Future<void> deleteRepayment(String repaymentId) =>
      _delete('/loans/repayments/$repaymentId');

  /// 应收款/应付款虚拟账户汇总。
  Future<List<Map<String, dynamic>>> loanVirtualAccounts() =>
      _get('/loans/virtual-accounts').then(_asList);

  Future<List<Map<String, dynamic>>> loanReminders() =>
      _get('/loans/reminders').then(_asList);

  // ==================== 储蓄罐 (0034/0036) ====================

  Future<List<Map<String, dynamic>>> listSavingPlans() =>
      _get('/saving-plans').then(_asList);

  Future<Map<String, dynamic>> createSavingPlan(Map<String, dynamic> body) =>
      _post('/saving-plans', body).then(_asMap);

  Future<Map<String, dynamic>> updateSavingPlan(
          String id, Map<String, dynamic> body) =>
      _patch('/saving-plans/$id', body).then(_asMap);

  Future<void> deleteSavingPlan(String id) => _delete('/saving-plans/$id');

  Future<List<Map<String, dynamic>>> contributions(String planId) =>
      _get('/saving-plans/$planId/contributions').then(_asList);

  /// 存入。双账户时 body 带 receiveAccountId → Cloud 生成一笔 transfer。
  Future<Map<String, dynamic>> contribute(
          String planId, Map<String, dynamic> body) =>
      _post('/saving-plans/$planId/contribute', body).then(_asMap);

  Future<Map<String, dynamic>> updateContribution(
          String id, Map<String, dynamic> body) =>
      _patch('/saving-plans/contributions/$id', body).then(_asMap);

  Future<void> deleteContribution(String id) =>
      _delete('/saving-plans/contributions/$id');

  Future<void> savingPlanAction(String id, String action) =>
      _post('/saving-plans/$id/$action'); // abandon/complete/archive

  // ==================== 报销 + 公司 (0035/0037) ====================

  Future<List<Map<String, dynamic>>> reimbursementItems() =>
      _get('/reimbursements/items').then(_asList);

  Future<Map<String, dynamic>> reimbursementItemByTx(String txSyncId) =>
      _get('/reimbursements/items/by-tx/$txSyncId').then(_asMap);

  Future<Map<String, dynamic>> createReimbursementItem(
          Map<String, dynamic> body) =>
      _post('/reimbursements/items', body).then(_asMap);

  Future<void> deleteReimbursementItem(String id) =>
      _delete('/reimbursements/items/$id');

  Future<List<Map<String, dynamic>>> reimbursements() =>
      _get('/reimbursements').then(_asList);

  Future<Map<String, dynamic>> createReimbursement(Map<String, dynamic> body) =>
      _post('/reimbursements', body).then(_asMap);

  Future<Map<String, dynamic>> updateReimbursement(
          String id, Map<String, dynamic> body) =>
      _patch('/reimbursements/$id', body).then(_asMap);

  Future<void> deleteReimbursement(String id) => _delete('/reimbursements/$id');

  Future<List<Map<String, dynamic>>> listCompanies() =>
      _get('/companies').then(_asList);

  Future<Map<String, dynamic>> createCompany(Map<String, dynamic> body) =>
      _post('/companies', body).then(_asMap);

  // ==================== 物品 (0038/0040) ====================

  Future<List<Map<String, dynamic>>> listItems() =>
      _get('/items').then(_asList);

  Future<Map<String, dynamic>> createItem(Map<String, dynamic> body) =>
      _post('/items', body).then(_asMap);

  Future<Map<String, dynamic>> updateItem(
          String id, Map<String, dynamic> body) =>
      _patch('/items/$id', body).then(_asMap);

  Future<void> deleteItem(String id) => _delete('/items/$id');

  Future<List<Map<String, dynamic>>> itemFlows(String itemId) =>
      _get('/items/$itemId/flows').then(_asList);

  Future<Map<String, dynamic>> addItemFlow(
          String itemId, Map<String, dynamic> body) =>
      _post('/items/$itemId/flows', body).then(_asMap);

  // ==================== 定期 (0031) ====================

  Future<List<Map<String, dynamic>>> listDeposits() =>
      _get('/deposits').then(_asList);

  Future<Map<String, dynamic>> createDeposit(Map<String, dynamic> body) =>
      _post('/deposits', body).then(_asMap);

  Future<Map<String, dynamic>> updateDeposit(
          String id, Map<String, dynamic> body) =>
      _patch('/deposits/$id', body).then(_asMap);

  Future<void> deleteDeposit(String id) => _delete('/deposits/$id');

  Future<Map<String, dynamic>> depositSummary() =>
      _get('/deposits/summary').then(_asMap);

  Future<Map<String, dynamic>> depositAction(String id, String action) =>
      _post('/deposits/$id/$action').then(_asMap); // withdraw/renew

  // ==================== 消费成员 (0024) ====================

  Future<List<Map<String, dynamic>>> listMembers() =>
      _get('/members').then(_asList);

  Future<Map<String, dynamic>> createMember(Map<String, dynamic> body) =>
      _post('/members', body).then(_asMap);

  Future<Map<String, dynamic>> memberStats({String scope = 'month'}) =>
      _get('/member-stats', {'scope': scope}).then(_asMap);

  // ==================== 锁账 (0067) 展示层 ====================

  /// 锁账配置：{is_locked, lock_date}。App 用它展示横幅/禁用编辑。
  /// 注意：真正的拦截在服务端(423)，这里只做体验层。
  Future<Map<String, dynamic>> lockSettings() =>
      _get('/profile/lock').then(_asMap);

  /// 设置锁账:{is_locked: bool, lock_date: ISO 日期 或 null}。
  /// 开启锁账必须先有日期(服务端校验)。
  Future<Map<String, dynamic>> patchLockSettings({
    required bool isLocked,
    String? lockDate,
  }) =>
      _patch('/profile/lock', {
        'is_locked': isLocked,
        'lock_date': lockDate,
      }).then(_asMap);

  /// 判断某交易时间是否落在锁定期(lockDate 当天及之前)。
  /// lockDate 为 ISO 日期字符串(如 2026-11-20T00:00:00)。
  static bool isLocked(String? lockDate, DateTime happenedAt) {
    if (lockDate == null || lockDate.isEmpty) return false;
    final cutoff = DateTime.tryParse(lockDate);
    if (cutoff == null) return false;
    return !happenedAt.isAfter(cutoff);
  }
}
