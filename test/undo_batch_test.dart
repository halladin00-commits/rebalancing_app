import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/services/undo_service.dart';

/// 되돌리기 묶음은 **저장됐다 되살아난다.**
///
/// 조정 제안 일괄 기록과 거래내역 업로드는 한 번에 수십 건을 넣는다.
/// 이 기록이 깨지면 되돌릴 방법이 없어져 사용자가 하나씩 지워야 한다.
void main() {
  UndoBatch sample({
    String kind = UndoBatch.kindProposal,
    List<({String itemId, String txId})>? tx,
    List<String> created = const [],
    String? cashId,
    double? cashBefore,
    int? lastRebalanced,
  }) =>
      UndoBatch(
        portfolioId: 'pf1',
        kind: kind,
        at: 1756600000000,
        transactions: tx ??
            [(itemId: 'a', txId: 't1'), (itemId: 'b', txId: 't2')],
        createdItemIds: created,
        cashItemId: cashId,
        cashBefore: cashBefore,
        lastRebalancedBefore: lastRebalanced,
      );

  UndoBatch roundTrip(UndoBatch b) => UndoBatch.fromJson(b.toJson());

  test('거래 목록이 개수와 짝 모두 그대로 돌아온다', () {
    final b = roundTrip(sample());
    expect(b.transactions.length, 2);
    expect(b.transactions[0].itemId, 'a');
    expect(b.transactions[0].txId, 't1');
    expect(b.transactions[1].itemId, 'b');
    expect(b.transactions[1].txId, 't2');
  });

  test('묶음 종류와 시각이 살아남는다 — 화면이 뭘 되돌리는지 말해야 한다', () {
    final b = roundTrip(sample(kind: UndoBatch.kindImport));
    expect(b.kind, UndoBatch.kindImport);
    expect(b.at, 1756600000000);
  });

  test('업로드가 만든 종목 목록이 살아남는다', () {
    final b = roundTrip(sample(created: ['i1', 'i2', 'i3']));
    expect(b.createdItemIds, ['i1', 'i2', 'i3']);
  });

  test('예수금 되돌릴 값이 한 자리도 안 틀린다', () {
    final b = roundTrip(sample(cashId: 'cash', cashBefore: 81527436.5));
    expect(b.cashItemId, 'cash');
    expect(b.cashBefore, 81527436.5);
  });

  test('예수금 0도 null과 구분된다 — 0을 잃으면 되돌려도 0이 안 된다', () {
    final b = roundTrip(sample(cashId: 'cash', cashBefore: 0));
    expect(b.cashBefore, 0);
    expect(b.cashBefore, isNotNull);
  });

  test('조정 시각이 없던 상태(null)도 그대로 돌아온다', () {
    // 첫 리밸런싱을 되돌리면 「조정 기록 없음」으로 돌아가야 한다.
    // 0으로 바뀌면 1970년이 된다.
    expect(roundTrip(sample()).lastRebalancedBefore, isNull);
    expect(roundTrip(sample(lastRebalanced: 123)).lastRebalancedBefore, 123);
  });

  test('거래가 없고 종목만 만든 업로드도 담긴다', () {
    final b = roundTrip(sample(tx: const [], created: ['only']));
    expect(b.transactions, isEmpty);
    expect(b.createdItemIds, ['only']);
    expect(b.count, 0);
  });

  test('count는 거래 건수다', () {
    expect(sample().count, 2);
  });

  test('종류가 빠진 옛 형식은 조정 제안으로 본다', () {
    final j = sample().toJson()..remove('k');
    expect(UndoBatch.fromJson(j).kind, UndoBatch.kindProposal);
  });
}
