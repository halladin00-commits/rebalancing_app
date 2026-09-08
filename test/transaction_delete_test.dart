import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rebalancing_app/main.dart';
import 'package:rebalancing_app/models/portfolio.dart';

/// 거래를 지우면 **보유 수량과 평균 단가가 다시 계산돼야 한다.**
///
/// 이 기능은 provider에 메서드만 있고 부르는 곳이 없었다 — 잘못 넣은 거래를
/// 고칠 수는 있어도 없앨 수가 없었다. 이제 거래 수정 화면에서 지울 수 있다.
///
/// 지우기가 수량만 고치고 평단을 안 고치면, 없앤 거래의 단가가 평단에 계속
/// 남아 수익률과 결산이 어긋난다. 눈으로는 안 보이는 종류의 오차다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PortfolioProvider provider;

  StockTransaction tx(String id, double qty, double price) => StockTransaction(
        id: id,
        date: DateTime(2026, 1, 1),
        quantity: qty,
        price: price,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = PortfolioProvider();
    await Future<void>.delayed(Duration.zero);
    await provider.addPortfolio(Portfolio(
      id: 'p',
      name: 'p',
      items: [
        PortfolioItem(
          id: 'a',
          name: 'A',
          ticker: 'A',
          market: 'KR',
          shares: 30,
          avgPrice: 2000,
          transactions: [
            tx('t1', 10, 1000), // 10주 @1,000
            tx('t2', 20, 2500), // 20주 @2,500 → 평단 2,000
          ],
        ),
      ],
    ));
  });

  PortfolioItem itemOf() => provider.getPortfolio('p')!.items.first;

  test('지우기 전 상태 — 30주, 평단 2,000', () {
    expect(itemOf().shares, 30);
    expect(itemOf().avgPrice, closeTo(2000, 0.01));
  });

  test('거래를 지우면 수량과 평단이 남은 거래로 다시 계산된다', () async {
    await provider.deleteTransaction('p', 'a', 't2');

    expect(itemOf().transactions.length, 1);
    expect(itemOf().shares, 10);
    // 평단이 2,000에 머물면 없앤 거래의 단가가 그대로 남은 것이다.
    expect(itemOf().avgPrice, closeTo(1000, 0.01));
  });

  test('전부 지우면 0주가 된다', () async {
    await provider.deleteTransaction('p', 'a', 't1');
    await provider.deleteTransaction('p', 'a', 't2');

    expect(itemOf().transactions, isEmpty);
    expect(itemOf().shares, 0);
  });

  test('없는 거래를 지우라고 해도 남은 것이 안 바뀐다', () async {
    await provider.deleteTransaction('p', 'a', '없는id');

    expect(itemOf().transactions.length, 2);
    expect(itemOf().shares, 30);
  });

  test('다시 읽어도 지운 것이 그대로다', () async {
    await provider.deleteTransaction('p', 'a', 't2');

    final reloaded = PortfolioProvider();
    await Future<void>.delayed(Duration.zero);
    final item = reloaded.getPortfolio('p')!.items.first;
    expect(item.transactions.length, 1);
    expect(item.shares, 10);
  });
}
