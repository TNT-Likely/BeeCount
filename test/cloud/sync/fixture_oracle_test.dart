import 'package:flutter_test/flutter_test.dart';

import '../../../qa/cloud_sync/fixture.dart';

void main() {
  final fixture = RichLedgerFixture.generate(transactionCount: 48);

  test('fixture rejects a child category assigned to the wrong parent', () {
    final key = fixture.id('breakfast');
    final expected = fixture.categories[key]!;
    final wrongParent = {...expected, 'parentId': fixture.id('transport')};
    expect(
      () => fixture.compare('categories', {key: expected}, [wrongParent]),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'offending category and field',
        allOf(contains('breakfast'), contains('parentId')),
      )),
    );
  });

  test('incremental journal rejects an unrelated replay or repeated event', () {
    final key = fixture.id('breakfast-01');
    final expected = {'transaction/$key': 'upsert'};
    final changed = {
      'entity_type': 'transaction',
      'entity_sync_id': key,
      'action': 'upsert',
    };
    final stale = {...changed, 'entity_sync_id': fixture.id('rent-month-end')};
    fixture.assertEvents('journal', expected, [changed]);
    expect(
      () => fixture.assertEvents('journal', expected, [changed, stale]),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'unexpected record',
        allOf(contains('unexpected'), contains('rent-month-end')),
      )),
    );
    expect(
      () => fixture.assertEvents('journal', expected, [changed, changed]),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'duplicate record',
        allOf(contains('duplicate'), contains('breakfast-01')),
      )),
    );
  });
}
