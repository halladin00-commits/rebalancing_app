import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rebalancing_app/main.dart';
import 'package:rebalancing_app/models/portfolio.dart';

/// **보유 수량은 거래 내역의 합과 같아야 한다.**
///
/// 왜 시험으로 못 박나 — 앱은 같은 사실을 두 군데에 들고 있다.
/// `item.shares`(저장된 값)와 `item.transactions`(거래 목록)다. 둘이
/// 갈라지면 **화면마다 다른 숫자가 나온다.**
///
///   · 목록의 평가금액·비중은 `shares`를 쓴다
///   · 상세의 「거래 기준」 보유 수량·평균 매수단가는 거래 합을 쓴다
///
/// 실제로 어긋난 자료가 나왔다 — 거래 4건의 합은 222주인데 저장된 수량은
/// 221주였다. 평가금액은 221주로, 평균 매수단가는 222주로 계산돼 한 화면
/// 안에서 두 기준이 섞였다. 예외도 경고도 없이, 24,755원이 조용히 사라진다.
///
/// 쓰기 경로는 지금 다 맞다. 이 시험은 **앞으로도 맞는지**를 지킨다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PortfolioProvider provider;

  StockTransaction tx(String id, double qty, double price,
          [DateTime? when]) =>
      StockTransaction(
        id: id,
        date: when ?? DateTime(2026, 1, 1),
        quantity: qty,
        price: price,
      );

  /// 거래가 있는 종목이면 수량이 그 합과 같아야 한다.
  void expectConsistent(PortfolioProvider p, String where) {
    for (final pf in p.portfolios) {
      for (final item in pf.items) {
        if (item.isCash || item.transactions.isEmpty) continue;
        final sum =
            item.transactions.fold(0.0, (s, t) => s + t.quantity);
        expect(item.shares, sum,
            reason: '$where — ${item.name}: 저장된 수량 ${item.shares}주, '
                '거래 합 $sum주');
      }
    }
  }

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
          name: '양자컴',
          ticker: 'A',
          market: 'KR',
          shares: 137,
          avgPrice: 19830,
          transactions: [tx('t1', 137, 19830, DateTime(2025, 9, 18))],
        ),
      ],
    ));
  });

  test('거래를 더하면 수량이 따라온다', () async {
    // 실제 자료와 같은 순서로 쌓는다
    await provider.upsertTransaction(
        'p', 'a', tx('t2', 37, 25280, DateTime(2026, 2, 3)));
    await provider.upsertTransaction(
        'p', 'a', tx('t3', 31, 22425, DateTime(2026, 2, 27)));
    await provider.upsertTransaction(
        'p', 'a', tx('t4', 17, 22670, DateTime(2026, 4, 10)));

    expectConsistent(provider, '거래 4건을 넣은 뒤');

    final item = provider.portfolios.first.items.first;
    expect(item.shares, 222, reason: '137+37+31+17');

    // 평균 매수단가도 같은 222주를 기준으로 나와야 한다.
    // 여기서 기준이 갈리면 평가손익이 조용히 어긋난다.
    const cost = 137 * 19830 + 37 * 25280 + 31 * 22425 + 17 * 22670;
    expect(item.avgPrice, closeTo(cost / 222, 0.01));
  });

  test('거래를 고치면 수량이 따라온다', () async {
    // 137주를 136주로 정정 — 잘못 적은 수량을 바로잡는 흔한 일
    await provider.upsertTransaction(
        'p', 'a', tx('t1', 136, 19830, DateTime(2025, 9, 18)));

    expectConsistent(provider, '거래를 고친 뒤');
    expect(provider.portfolios.first.items.first.shares, 136);
  });

  test('거래를 지우면 수량이 따라온다', () async {
    await provider.upsertTransaction(
        'p', 'a', tx('t2', 37, 25280, DateTime(2026, 2, 3)));
    await provider.deleteTransaction('p', 'a', 't1');

    expectConsistent(provider, '거래를 지운 뒤');
    expect(provider.portfolios.first.items.first.shares, 37);
  });

  _fromJsonRepairs();

  test('매도가 섞여도 수량이 따라온다', () async {
    await provider.upsertTransaction(
        'p', 'a', tx('t2', -37, 25280, DateTime(2026, 2, 3)));

    expectConsistent(provider, '매도를 넣은 뒤');
    expect(provider.portfolios.first.items.first.shares, 100);

    // 매도는 평단을 흔들지 않는다 — 산 것만으로 낸다
    expect(provider.portfolios.first.items.first.avgPrice, 19830);
  });
}

/// 들어오는 자리에서 이미 어긋난 자료를 고치는가.
///
/// 옛 판에서 생긴 어긋남은 **저장 파일 안에** 있다. 쓰기 경로를 아무리
/// 고쳐도 읽을 때 그대로 들어오면 화면은 계속 틀린 값을 보여준다.
/// 실제 백업에서 12종목 중 2종목이 이랬다.
void _fromJsonRepairs() {
  group('저장된 자료를 읽을 때', () {
    Map<String, dynamic> tx(double q, double p) =>
        {'id': 'x$q', 'date': 1758121200000, 'quantity': q, 'price': p};

    test('수량이 거래 합보다 적으면 맞춘다 (실제 자료: 221 → 222)', () {
      final item = PortfolioItem.fromJson({
        'id': 'a', 'name': 'SOL 미국양자컴퓨팅TOP10', 'ticker': '0023A0',
        'market': 'KR', 'isCash': false,
        'shares': 221.0, 'avgPrice': 21318.175675675677,
        'transactions': [
          tx(137, 19830), tx(37, 25280), tx(31, 22425), tx(17, 22670),
        ],
      });
      expect(item.shares, 222);
    });

    test('수량이 거래 합보다 많으면 맞춘다 (실제 자료: 263 → 262)', () {
      final item = PortfolioItem.fromJson({
        'id': 'b', 'name': 'PLUS 글로벌휴머노이드로봇액티브', 'ticker': '0035T0',
        'market': 'KR', 'isCash': false,
        'shares': 263.0, 'avgPrice': 20519.22725498417,
        'transactions': [
          tx(89, 20825), tx(122, 20835), tx(-1, 21905), tx(52, 19250),
        ],
      });
      expect(item.shares, 262);
      // 평단도 같이 어긋나 있었다 — 산 것만으로 다시 낸다
      const cost = 89 * 20825 + 122 * 20835 + 52 * 19250;
      expect(item.avgPrice, closeTo(cost / 263, 0.01));
    });

    test('예수금은 건드리지 않는다 — 거래가 없고 수량이 곧 금액이다', () {
      final cash = PortfolioItem.fromJson({
        'id': 'c', 'name': '예수금', 'market': 'CASH', 'isCash': true,
        'shares': 1500000.0, 'currentPrice': 1.0, 'transactions': [],
      });
      expect(cash.shares, 1500000);
    });

    test('거래가 없던 옛 종목은 지금까지처럼 합성 거래를 만든다', () {
      final old = PortfolioItem.fromJson({
        'id': 'd', 'name': '옛 종목', 'ticker': 'Z', 'market': 'KR',
        'isCash': false, 'shares': 50.0, 'avgPrice': 1000.0,
      });
      expect(old.transactions.length, 1);
      expect(old.shares, 50, reason: '합성 거래와 수량이 같아야 한다');
    });
  });
}
