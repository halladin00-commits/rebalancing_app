import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rebalancing_app/main.dart';
import 'package:rebalancing_app/models/portfolio.dart';

/// 예수금은 앱이 계산하지 않고 **사용자가 적는다.** 그래서 두 가지가 중요하다:
///
///   1. 적은 값이 그대로 저장될 것
///   2. **언제 적었는지**가 같이 남을 것 — 낡은 값은 티가 나야 고칠 수 있다
///
/// 2번은 눈으로 못 잡는다. 화면에 「3일 전에 적은 값」이 안 뜨는 걸 봐도
/// 그게 저장이 안 된 건지 계산이 틀린 건지 알 수 없다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PortfolioProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = PortfolioProvider();
    // 생성자가 비동기로 읽는다 — 끝날 때까지 한 틱 기다린다
    await Future<void>.delayed(Duration.zero);
    await provider.addPortfolio(Portfolio(
      id: 'p',
      name: '테스트',
      items: [
        PortfolioItem(
          id: 'cash',
          name: '예수금',
          market: 'CASH',
          isCash: true,
          shares: 1000,
        ),
      ],
    ));
  });

  PortfolioItem cashOf() =>
      provider.getPortfolio('p')!.items.firstWhere((i) => i.isCash);

  test('금액을 바꾸면 적은 시각이 남는다', () async {
    expect(cashOf().cashUpdatedAt, isNull);

    final before = DateTime.now().millisecondsSinceEpoch;
    await provider.updateCash('p', 'cash', amount: 2500);

    expect(cashOf().shares, 2500);
    expect(cashOf().cashUpdatedAt, isNotNull);
    expect(cashOf().cashUpdatedAt! >= before, isTrue);
  });

  test('같은 금액을 다시 저장하면 시각을 건드리지 않는다', () async {
    await provider.updateCash('p', 'cash', amount: 2500);
    final stamp = cashOf().cashUpdatedAt;

    await Future<void>.delayed(const Duration(milliseconds: 5));
    // 비중 스위치만 만지고 나갔을 때 「방금 적은 값」이 되면 안 된다 —
    // 확인한 적 없는 값이 최신인 척하게 된다.
    await provider.updateCash('p', 'cash', amount: 2500, inWeight: false);

    expect(cashOf().cashUpdatedAt, stamp);
    expect(cashOf().inWeight, isFalse);
  });

  test('금액을 비워 두면(null) 금액은 그대로 두고 비중만 바꾼다', () async {
    await provider.updateCash('p', 'cash', amount: 1000, inWeight: true);
    await provider.updateCash('p', 'cash', inWeight: false);

    expect(cashOf().shares, 1000);
    expect(cashOf().inWeight, isFalse);
  });

  test('다시 읽어도 값이 살아 있다', () async {
    await provider.updateCash('p', 'cash', amount: 777, inWeight: false);

    final reloaded = PortfolioProvider();
    await Future<void>.delayed(Duration.zero);
    final item = reloaded
        .getPortfolio('p')!
        .items
        .firstWhere((i) => i.isCash);
    expect(item.shares, 777);
    expect(item.inWeight, isFalse);
    expect(item.cashUpdatedAt, isNotNull);
  });
}
