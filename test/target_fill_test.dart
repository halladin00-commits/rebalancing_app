import 'package:flutter_test/flutter_test.dart';

/// 목표 비중을 한 번에 채우는 두 규칙 — **합계는 반드시 정확히 100이어야 한다.**
///
/// 목표 비중 화면은 합계가 100이 아니면 저장을 막는다. 반올림만 하면
/// 99.99나 100.01이 나와 **버튼을 눌렀는데 저장이 안 되는** 상태가 된다.
void main() {
  /// 균등 배분: 마지막 칸이 나머지를 받는다.
  List<double> evenly(int n) {
    final each = (100 / n * 100).floorToDouble() / 100;
    var assigned = 0.0;
    final out = <double>[];
    for (var i = 0; i < n; i++) {
      final v = i == n - 1 ? (100 - assigned) : each;
      assigned += v;
      out.add(double.parse(v.toStringAsFixed(2)));
    }
    return out;
  }

  /// 현재 비중 복사: **가장 큰 종목**이 나머지를 받는다.
  List<double> useCurrent(List<double> current) {
    final idx = List.generate(current.length, (i) => i)
      ..sort((a, b) => current[b].compareTo(current[a]));
    final out = List<double>.filled(current.length, 0);
    var assigned = 0.0;
    for (var k = 1; k < idx.length; k++) {
      final v = double.parse(current[idx[k]].toStringAsFixed(2));
      out[idx[k]] = v;
      assigned += v;
    }
    out[idx.first] = double.parse((100 - assigned).toStringAsFixed(2));
    return out;
  }

  double sum(List<double> l) =>
      double.parse(l.fold(0.0, (a, b) => a + b).toStringAsFixed(2));

  group('균등 배분', () {
    test('나눠떨어지는 경우', () {
      expect(evenly(4), [25, 25, 25, 25]);
      expect(sum(evenly(4)), 100);
    });

    test('나눠떨어지지 않아도 합계가 정확히 100 — 3종목', () {
      final r = evenly(3);
      expect(sum(r), 100);
      expect(r.take(2), [33.33, 33.33]);
      expect(r.last, 33.34);
    });

    test('7 · 9 · 11 종목에서도 100', () {
      for (final n in [7, 9, 11]) {
        expect(sum(evenly(n)), 100, reason: '$n종목');
      }
    });

    test('10종목 균등 — 이 사용자의 ISA', () {
      expect(sum(evenly(10)), 100);
      expect(evenly(10).every((v) => v == 10), isTrue);
    });
  });

  group('현재 비중으로', () {
    test('합계가 정확히 100', () {
      expect(sum(useCurrent([58.53, 5.28, 6.38, 9.30, 4.60, 2.36, 5.49, 3.90, 4.16])), 100);
    });

    test('가장 큰 종목이 나머지를 받는다 — 오차를 가장 작게 흡수한다', () {
      final r = useCurrent([58.53, 20.11, 21.36]);
      // 나머지 둘은 그대로, 가장 큰 첫 번째가 조정된다
      expect(r[1], 20.11);
      expect(r[2], 21.36);
      expect(r[0], closeTo(58.53, 0.02));
      expect(sum(r), 100);
    });

    test('두 종목만 있어도 100', () {
      expect(sum(useCurrent([90.12, 9.88])), 100);
    });

    test('현재 비중이 이미 딱 떨어지면 그대로다', () {
      expect(useCurrent([60, 40]), [60, 40]);
    });
  });
}
