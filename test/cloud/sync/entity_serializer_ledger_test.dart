import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/cloud/sync/entity_serializer.dart';
import 'package:beecount/data/db.dart';

void main() {
  test('serializeLedger 携带 monthStartDay', () {
    final ledger = Ledger(
      id: 1,
      name: '测试',
      currency: 'CNY',
      type: 'personal',
      createdAt: DateTime(2026, 1, 1),
      syncId: 'L1',
      myRole: 'owner',
      memberCount: 1,
      isShared: false,
      ownerUserId: null,
      monthStartDay: 15,
    );
    final m = EntitySerializer.serializeLedger(ledger);
    expect(m['monthStartDay'], 15);
    expect(m['ledgerName'], '测试');
  });

  test('serializeLedger monthStartDay=1 默认值', () {
    final ledger = Ledger(
      id: 2,
      name: '默认账本',
      currency: 'USD',
      type: 'personal',
      createdAt: DateTime(2026, 1, 1),
      syncId: 'L2',
      myRole: 'owner',
      memberCount: 1,
      isShared: false,
      ownerUserId: null,
      monthStartDay: 1,
    );
    final m = EntitySerializer.serializeLedger(ledger);
    expect(m['monthStartDay'], 1);
    expect(m['currency'], 'USD');
    expect(m['syncId'], 'L2');
  });
}
