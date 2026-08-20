import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/settlement_service.dart';
import '../theme/design_system.dart';

/// 기간 점프 시트 (v22c).
///
/// 차트는 이웃한 6개 기간을 오가는 도구다. 그보다 멀리 갈 때 이 시트를 연다.
/// **1~52 주차 목록은 만들지 않는다** — 주간도 연도 → 기간 순으로 좁혀 고른다.
///
/// 시트가 어느 범위로 열렸는지([scopeName])를 반드시 밝힌다.
/// 전체 결산과 포트별 결산은 기간을 각자 기억하기 때문이다.
class PeriodJumpSheet extends StatefulWidget {
  final SettlementPeriod period;
  final PeriodKey selected;

  /// 데이터가 있는 가장 이른 연도
  final int earliestYear;

  /// "연금저축 ETF 기준"처럼 이 시트가 다루는 범위
  final String scopeName;

  /// 칸에 적을 손익. 계산된 기간만 넣는다.
  final double? Function(PeriodKey key)? amountOf;

  const PeriodJumpSheet({
    super.key,
    required this.period,
    required this.selected,
    required this.earliestYear,
    required this.scopeName,
    this.amountOf,
  });

  /// 선택된 키를 돌려준다. 취소하면 null.
  static Future<PeriodKey?> show(
    BuildContext context, {
    required SettlementPeriod period,
    required PeriodKey selected,
    required int earliestYear,
    required String scopeName,
    double? Function(PeriodKey key)? amountOf,
  }) {
    return showModalBottomSheet<PeriodKey>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: const Color(0x8016130F),
      builder: (_) => PeriodJumpSheet(
        period: period,
        selected: selected,
        earliestYear: earliestYear,
        scopeName: scopeName,
        amountOf: amountOf,
      ),
    );
  }

  @override
  State<PeriodJumpSheet> createState() => _PeriodJumpSheetState();
}

class _PeriodJumpSheetState extends State<PeriodJumpSheet> {
  late SettlementPeriod _period;
  late int _year;
  late PeriodKey _picked;

  @override
  void initState() {
    super.initState();
    _period = widget.period;
    _year = widget.selected.year;
    _picked = widget.selected;
  }

  bool get _isKo => Localizations.localeOf(context).languageCode == 'ko';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final years = [
      for (var y = DateTime.now().year; y >= widget.earliestYear; y--) y,
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.scaffoldBg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(DS.sheetRadius)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6CFBC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 제목 + 범위 — 어느 범위의 기간을 고르는지 밝힌다
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DS.screenPaddingH),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _isKo ? '기간 선택' : 'Select period',
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isKo ? '${widget.scopeName} 기준' : 'For ${widget.scopeName}',
                    style: TextStyle(
                        fontSize: DS.body,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 단위 세그먼트
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DS.screenPaddingH),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: context.trackBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  for (final p in SettlementPeriod.values)
                    Expanded(child: _unitButton(p, l10n)),
                ],
              ),
            ),
          ),

          // 연도 칩 (연간은 필요 없다)
          if (_period != SettlementPeriod.yearly) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: DS.screenPaddingH),
                itemCount: years.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (_, i) => _yearChip(years[i]),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 기간 칸
          Flexible(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: DS.screenPaddingH),
              child: _periodGrid(l10n),
            ),
          ),

          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DS.screenPaddingH),
            child: SizedBox(
              width: double.infinity,
              height: DS.buttonHeight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _picked),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DS.buttonRadius)),
                ),
                child: Text(
                  _ctaLabel(l10n),
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ctaLabel(dynamic l10n) {
    final label = _subLabel(_picked, l10n);
    return _isKo ? '${_picked.year}년 $label 보기' : 'View $label ${_picked.year}';
  }

  Widget _unitButton(SettlementPeriod p, dynamic l10n) {
    final active = _period == p;
    return GestureDetector(
      onTap: () {
        if (_period == p) return;
        setState(() {
          _period = p;
          // 단위가 바뀌면 선택도 그 단위의 현재 기간으로 맞춘다
          _picked = SettlementService.currentKey(p);
          _year = _picked.year;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? context.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          _unitName(p, l10n),
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? Colors.white : context.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _yearChip(int y) {
    final active = _year == y;
    return GestureDetector(
      onTap: () => setState(() {
        _year = y;
        final maxSub = SettlementService.maxSub(_period, y);
        _picked = PeriodKey(y, _picked.sub.clamp(1, maxSub));
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? context.brand : context.cardBg,
          borderRadius: BorderRadius.circular(DS.chipRadius),
          border: Border.all(
              color: active ? context.brand : context.cardBorder),
        ),
        child: Text(
          '$y',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : context.textStrong,
          ),
        ),
      ),
    );
  }

  Widget _periodGrid(dynamic l10n) {
    final keys = _keysForYear();
    return Column(
      children: [
        for (var row = 0; row < (keys.length / 2).ceil(); row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: _periodTile(keys[row * 2], l10n)),
                const SizedBox(width: 8),
                Expanded(
                  child: row * 2 + 1 < keys.length
                      ? _periodTile(keys[row * 2 + 1], l10n)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 선택된 단위·연도에서 고를 수 있는 기간들
  List<PeriodKey> _keysForYear() {
    switch (_period) {
      case SettlementPeriod.yearly:
        return [
          for (var y = DateTime.now().year; y >= widget.earliestYear; y--)
            PeriodKey(y, 0),
        ];
      case SettlementPeriod.weekly:
        final weeks = SettlementService.isoWeeksInYear(_year);
        return [for (var w = 1; w <= weeks; w++) PeriodKey(_year, w)];
      case SettlementPeriod.monthly:
        return [for (var m = 1; m <= 12; m++) PeriodKey(_year, m)];
      case SettlementPeriod.quarterly:
        return [for (var q = 1; q <= 4; q++) PeriodKey(_year, q)];
    }
  }

  Widget _periodTile(PeriodKey key, dynamic l10n) {
    final isFuture = SettlementService.isFuture(_period, key);
    final range = SettlementService.periodRange(_period, key);
    final inProgress = !isFuture &&
        !range.end.isBefore(DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day));
    final selected = _picked == key;
    final amount = isFuture ? null : widget.amountOf?.call(key);

    final pnlColors = context.watch<PnlColorNotifier>();

    Color bg;
    Color fg;
    if (selected) {
      bg = context.brand;
      fg = Colors.white;
    } else if (isFuture) {
      bg = const Color(0xFFF4F0E6);
      fg = context.textDisabled;
    } else {
      bg = context.cardBg;
      fg = context.textPrimary;
    }

    return GestureDetector(
      onTap: isFuture ? null : () => setState(() => _picked = key),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? context.brand
                : inProgress
                    ? context.progressAccent
                    : context.cardBorder,
            width: inProgress && !selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    _subLabel(key, l10n),
                    style: TextStyle(
                        fontSize: DS.sectionTitle,
                        fontWeight: FontWeight.w700,
                        color: fg),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (inProgress && !isFuture) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : context.progressAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _rangeLabel(range.start, range.end),
              style: TextStyle(
                fontSize: DS.caption,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white.withValues(alpha: 0.75)
                    : (isFuture ? context.textDisabled : context.textTertiary),
              ),
            ),
            if (amount != null) ...[
              const SizedBox(height: 2),
              Text(
                '${amount >= 0 ? '+' : '−'}${_fmtCompact(amount.abs())}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : (amount >= 0
                          ? pnlColors.positiveColor
                          : pnlColors.negativeColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _unitName(SettlementPeriod p, dynamic l10n) {
    switch (p) {
      case SettlementPeriod.weekly:
        return l10n.settlementWeekly;
      case SettlementPeriod.monthly:
        return l10n.settlementMonthly;
      case SettlementPeriod.quarterly:
        return l10n.settlementQuarterly;
      case SettlementPeriod.yearly:
        return l10n.settlementYearly;
    }
  }

  String _subLabel(PeriodKey key, dynamic l10n) {
    switch (_period) {
      case SettlementPeriod.weekly:
        return l10n.settlementWeekNum(key.sub);
      case SettlementPeriod.monthly:
        return _isKo ? '${key.sub}월' : _monthAbbr(key.sub);
      case SettlementPeriod.quarterly:
        return l10n.settlementQuarterNum(key.sub);
      case SettlementPeriod.yearly:
        return l10n.settlementYearLabel(key.year);
    }
  }

  static String _monthAbbr(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];

  String _rangeLabel(DateTime a, DateTime b) =>
      '${a.month.toString().padLeft(2, '0')}.${a.day.toString().padLeft(2, '0')}'
      ' – '
      '${b.month.toString().padLeft(2, '0')}.${b.day.toString().padLeft(2, '0')}';

  /// 칸이 좁아 축약해 적는다 (한국어 만 단위, 영어 K/M)
  String _fmtCompact(double v) {
    if (_isKo) {
      if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}억';
      if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}만';
      return v.round().toString();
    }
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.round().toString();
  }
}
