import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../widgets/app_logo.dart';
import '../widgets/weight_bar.dart';

/// 첫 실행 화면.
///
/// **기능을 나열하지 않는다.** 예전에는 아이콘 셋에 「자산현황부터 리밸런싱
/// 계산까지」 같은 홍보 문구를 얹었는데, 정작 앱을 쓰려면 알아야 할 말
/// (목표 비중 · 허용 편차 · 편차 %p)을 하나도 안 가르쳤다. 처음 여는 사람이
/// 리밸런싱 탭에서 막히는 건 기능을 몰라서가 아니라 **말을 몰라서**다.
///
/// 그래서 앱이 실제로 그리는 것을 그대로 보여준다 — 같은 비중 막대,
/// 같은 목표선, 같은 매도·매수 배지. 온보딩에서 본 모양이 앱 안에 그대로
/// 다시 나오면 설명이 한 번으로 끝난다.
///
/// 1쪽은 스플래시와 같은 딥그린 한 판이라 앱이 켜지는 흐름이 끊기지 않고,
/// 2·3쪽은 크림 배경이라 실제 앱 화면으로 넘어가는 느낌이 이어진다.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 3;

  final _pageCtrl = PageController();
  int _page = 0;
  final _selected = <int>{};

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  String _uid(int extra) =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      extra.toRadixString(36);

  void _go(int page) => _pageCtrl.animateToPage(
        page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );

  Future<void> _start(bool isKo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;

    final provider = context.read<PortfolioProvider>();
    final samples = _getSamples(isKo);
    for (final idx in (_selected.toList()..sort())) {
      await provider.addPortfolio(samples[idx].build(_uid(idx)));
    }
    widget.onComplete();
  }

  // ══ 시작 템플릿 ══

  /// **국내 사용자에게는 국내 상장 ETF를 준다.** 원안(VTI·TLT·GLD…)은 미국
  /// 상장이라 ISA·연금 계좌에서 살 수 없고, 달러 환전이 따로 든다. 첫 화면에서
  /// 고른 템플릿을 그대로 못 사면 템플릿이 있으나 마나다.
  List<_Sample> _getSamples(bool isKo) => isKo ? _krSamples() : _usSamples();

  /// 국내 상장 ETF판.
  ///
  /// 종목은 자산군마다 **순자산이 가장 큰 것**으로 골랐다 — 같은 지수를 여러
  /// 운용사가 내므로, 규모는 특정 운용사를 미는 것으로 보이지 않는 중립적
  /// 기준이고 유동성·호가도 대체로 가장 좋다.
  ///
  /// 규모로 확인한 것 (2026-08):
  ///   S&P500  TIGER 미국S&P500 20.4조 — KODEX보다 크다
  ///   금현물   ACE KRX금현물 — TIGER KRX금현물이 1.25조로 2위
  /// 나머지(국고채30년·10년·종합채권·MSCI선진국)는 각 카테고리 대표 상품을
  /// 썼으나 순자산 수치를 확인하지 못했다. 규모가 뒤바뀌면 바꾸면 된다.
  ///
  /// 티커는 앱에 들어 있는 국내 종목 데이터(`assets/kr_stocks.json`)로 확인했다.
  List<_Sample> _krSamples() => [
        const _Sample(
          name: '올웨더 포트폴리오',
          desc: '레이 달리오의 전천후 자산배분 · 국내 상장 ETF판',
          currency: 'KRW',
          items: [
            _Item('TIGER 미국S&P500', '360750', 'KR', false, 30, 'S&P500'),
            _Item('KODEX 국고채30년액티브', '439870', 'KR', false, 40, '국고채30년'),
            _Item('ACE 국고채10년', '365780', 'KR', false, 15, '국고채10년'),
            // 원안은 금 7.5% + 원자재 7.5%다. 국내에는 광범위 원자재 ETF가
            // 없어(농산물·원유·구리 같은 단일 품목뿐) 실물자산 몫 15%를
            // 금현물 하나로 모았다. 선물 ETF로 쪼개면 롤오버 비용이 붙고
            // 첫 템플릿에 종목이 여섯 개가 된다. **바꿨다는 사실은 설명에 밝힌다.**
            _Item('ACE KRX금현물', '411060', 'KR', false, 15, '금'),
          ],
        ),
        const _Sample(
          name: '영구 포트폴리오',
          desc: '해리 브라운의 4자산 균형 배분 · 국내 상장 ETF판',
          currency: 'KRW',
          items: [
            _Item('TIGER 미국S&P500', '360750', 'KR', false, 25, 'S&P500'),
            _Item('KODEX 국고채30년액티브', '439870', 'KR', false, 25, '국고채30년'),
            _Item('ACE KRX금현물', '411060', 'KR', false, 25, '금'),
            _Item('현금', '', 'CASH', true, 25, '현금'),
          ],
        ),
        const _Sample(
          name: '글로벌 60/40',
          desc: '전통적 주식 60%, 채권 40% 배분 · 국내 상장 ETF판',
          currency: 'KRW',
          items: [
            _Item('TIGER 미국S&P500', '360750', 'KR', false, 40, 'S&P500'),
            _Item('KODEX MSCI선진국', '251350', 'KR', false, 20, 'MSCI선진국'),
            _Item('KODEX 종합채권(AA-이상)액티브', '273130', 'KR', false, 40, '종합채권'),
          ],
        ),
      ];

  /// 미국 상장 ETF판 (영어 사용자).
  List<_Sample> _usSamples() => [
        const _Sample(
          name: 'All Weather',
          desc: "Ray Dalio's all-weather allocation",
          items: [
            _Item('VTI', 'VTI', 'US', false, 30, 'VTI'),
            _Item('TLT', 'TLT', 'US', false, 40, 'TLT'),
            _Item('IEF', 'IEF', 'US', false, 15, 'IEF'),
            _Item('GLD', 'GLD', 'US', false, 7.5, 'GLD'),
            _Item('DJP', 'DJP', 'US', false, 7.5, 'DJP'),
          ],
        ),
        const _Sample(
          name: 'Permanent Portfolio',
          desc: "Harry Browne's 4-asset balance",
          items: [
            _Item('VTI', 'VTI', 'US', false, 25, 'VTI'),
            _Item('TLT', 'TLT', 'US', false, 25, 'TLT'),
            _Item('GLD', 'GLD', 'US', false, 25, 'GLD'),
            _Item('Cash', '', 'CASH', true, 25, 'Cash'),
          ],
        ),
        const _Sample(
          name: 'Global 60/40',
          desc: 'Classic 60% stocks, 40% bonds',
          items: [
            _Item('VTI', 'VTI', 'US', false, 40, 'VTI'),
            _Item('VEA', 'VEA', 'US', false, 20, 'VEA'),
            _Item('BND', 'BND', 'US', false, 40, 'BND'),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isKo = context.watch<LocaleProvider>().locale.languageCode == 'ko';
    final onGreen = _page == 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) _go(_page - 1);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              onGreen ? Brightness.light : Brightness.dark,
          statusBarBrightness: onGreen ? Brightness.dark : Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: onGreen ? context.appBarBg : context.scaffoldBg,
          body: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (p) => setState(() => _page = p),
            children: [
              _buildIntro(context, isKo),
              _buildHow(context, isKo),
              _buildStart(context, isKo),
            ],
          ),
        ),
      ),
    );
  }

  // ══ 1쪽 · 무엇을 대신 해주나 ══

  Widget _buildIntro(BuildContext context, bool isKo) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 28, 26, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppLogo(iconSize: 26),
            const Spacer(flex: 3),
            Text(
              isKo ? '목표에서\n얼마나 벗어났나' : 'How far from\nyour target?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
                height: 1.28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isKo
                  ? '정해 둔 비중에서 얼마나 밀렸는지,\n'
                      '되돌리려면 몇 주를 사고팔아야 하는지.\n'
                      '그 계산을 대신합니다.'
                  : 'How far your holdings drifted from the\n'
                      'weights you set, and how many shares to\n'
                      'trade to bring them back. We do the math.',
              style: TextStyle(
                color: context.onBrandSecondary,
                fontSize: 14.5,
                height: 1.62,
              ),
            ),
            const Spacer(flex: 2),

            // 앱이 실제로 그리는 막대를 그대로 놓는다. 여기서 본 모양이
            // 리밸런싱 화면에 똑같이 나온다.
            const _DriftDemo(),

            const Spacer(flex: 3),
            _dots(context, onGreen: true),
            const SizedBox(height: 16),
            _primaryButton(
              context,
              label: isKo ? '어떻게 쓰는지 보기' : 'See how it works',
              onGreen: true,
              onTap: () => _go(1),
            ),
            const SizedBox(height: 6),
            _textButton(
              context,
              label: isKo ? '바로 시작하기' : 'Skip',
              onGreen: true,
              onTap: () => _go(2),
            ),
          ],
        ),
      ),
    );
  }

  // ══ 2쪽 · 세 걸음 ══

  Widget _buildHow(BuildContext context, bool isKo) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isKo ? '세 걸음이면 됩니다' : 'Three steps',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              children: [
                _step(
                  context,
                  n: 1,
                  title: isKo ? '계좌를 만들고 종목을 담습니다' : 'Add an account and holdings',
                  desc: isKo
                      ? '위탁계좌·ISA처럼 계좌별로 따로 관리합니다.\n'
                          '거래 내역을 넣으면 수량과 평균단가가 잡힙니다.'
                      : 'Keep each account separate.\n'
                          'Enter trades and we work out your position.',
                  demo: const _HoldingDemo(),
                ),
                const SizedBox(height: 14),
                _step(
                  context,
                  n: 2,
                  title: isKo ? '종목마다 목표 비중을 정합니다' : 'Set a target weight',
                  desc: isKo
                      ? '「이 종목은 30%」처럼 정해 둡니다.\n'
                          '얼마나 벗어나면 손볼지(허용 편차)도 같이요.'
                      : 'Say “this one should be 30%”,\n'
                          'and how far it may drift before you act.',
                  demo: const _TargetDemo(),
                ),
                const SizedBox(height: 14),
                _step(
                  context,
                  n: 3,
                  title: isKo ? '벗어나면 수량까지 계산해 드립니다' : 'We calculate the shares',
                  desc: isKo
                      ? '허용 편차를 넘으면 알려 드리고,\n'
                          '몇 주를 사고팔면 되는지 그대로 보여줍니다.'
                      : 'When it drifts too far we tell you,\n'
                          'and show exactly how many shares to trade.',
                  demo: const _TradeDemo(),
                ),
                const SizedBox(height: 10),
                Text(
                  isKo
                      ? '주문은 증권사에서 하세요. 이 앱은 사고파는 앱이 아니라 '
                          '무엇을 얼마나 사고팔지 알려주는 앱입니다.'
                      : 'Place orders with your broker. This app tells you '
                          'what to trade — it does not trade for you.',
                  style: TextStyle(
                    color: context.textTertiary,
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              children: [
                _dots(context, onGreen: false),
                const SizedBox(height: 14),
                _primaryButton(
                  context,
                  label: isKo ? '다음' : 'Next',
                  onGreen: false,
                  onTap: () => _go(2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(
    BuildContext context, {
    required int n,
    required String title,
    required String desc,
    required Widget demo,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.listCardRadius),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 번호는 **순서가 실제로 있는 것**이라 쓴다 — 계좌가 있어야
              // 목표를 정하고, 목표가 있어야 편차가 나온다.
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: context.brand,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$n',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        )),
                    const SizedBox(height: 4),
                    Text(desc,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12.5,
                          height: 1.5,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          demo,
        ],
      ),
    );
  }

  // ══ 3쪽 · 시작 방법 ══

  Widget _buildStart(BuildContext context, bool isKo) {
    final samples = _getSamples(isKo);
    final n = _selected.length;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isKo ? '어떻게 시작할까요' : 'How to start',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  isKo
                      ? '잘 알려진 자산배분을 담아 두고 시작할 수 있습니다.\n'
                          '종목과 비중은 나중에 마음대로 바꿉니다.'
                      : 'Start from a well-known allocation.\n'
                          'You can change everything later.',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              itemCount: samples.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, idx) => _sampleCard(context, idx, samples[idx]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              children: [
                _dots(context, onGreen: false),
                const SizedBox(height: 14),
                _primaryButton(
                  context,
                  label: n > 0
                      ? (isKo
                          ? '$n개 담고 시작하기'
                          : 'Add $n and start')
                      : (isKo ? '직접 만들기' : 'Set up my own'),
                  onGreen: false,
                  onTap: () => _start(isKo),
                ),
                if (n == 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    isKo
                        ? '다음 화면에서 계좌 만드는 법을 안내해 드립니다'
                        : 'We will walk you through adding an account next',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: context.textTertiary, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sampleCard(BuildContext context, int idx, _Sample s) {
    final sel = _selected.contains(idx);
    return GestureDetector(
      onTap: () =>
          setState(() => sel ? _selected.remove(idx) : _selected.add(idx)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
        decoration: BoxDecoration(
          color: sel ? context.brandTint : context.cardBg,
          borderRadius: BorderRadius.circular(DS.listCardRadius),
          border: Border.all(
            color: sel ? context.brand : context.cardBorder,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(s.desc,
                          style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: sel ? context.brand : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel ? context.brand : context.borderColor,
                      width: 1.5,
                    ),
                  ),
                  child: sel
                      ? const Icon(Icons.check, color: Colors.white, size: 13)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 이모지 대신 **그 템플릿의 목표 비중을 그대로** 그린다.
            // 앱 안에서 보게 될 모양과 같고, 그림 하나가 태그 다섯 줄보다
            // 「어떻게 나뉘는지」를 빨리 전한다.
            AllocationBar(weights: [for (final i in s.items) i.weight]),
            const SizedBox(height: 9),
            Wrap(
              spacing: 10,
              runSpacing: 5,
              children: [
                for (var i = 0; i < s.items.length; i++)
                  _legend(context, i, s.items[i]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, int i, _Item item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AllocationBar.toneOf(context, i),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '${item.label} ${_trim(item.weight)}%',
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ══ 공통 부품 ══

  Widget _dots(BuildContext context, {required bool onGreen}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _pageCount; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == _page ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _page
                  ? (onGreen ? Colors.white : context.brand)
                  : (onGreen
                      ? Colors.white.withValues(alpha: 0.32)
                      : context.borderColor),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }

  Widget _primaryButton(
    BuildContext context, {
    required String label,
    required bool onGreen,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: DS.buttonHeight,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: onGreen ? Colors.white : context.brand,
          foregroundColor: onGreen ? context.brand : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DS.buttonRadius)),
        ),
        child: Text(label,
            style:
                const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _textButton(
    BuildContext context, {
    required String label,
    required bool onGreen,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor:
              onGreen ? context.onBrandSecondary : context.textSecondary,
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

// ══ 앱 화면 조각들 ══
//
// 온보딩용으로 새로 그린 그림이 아니라 **앱이 실제로 쓰는 부품**이거나
// 그것과 같은 모양이다. 여기서 본 것이 앱 안에 그대로 다시 나와야
// 설명이 한 번으로 끝난다.

/// 1쪽 · 목표에서 벗어난 막대.
///
/// 리밸런싱 화면의 [WeightBar] 그대로다. 세로선이 목표, 칸이 지금 비중.
class _DriftDemo extends StatelessWidget {
  const _DriftDemo();

  @override
  Widget build(BuildContext context) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DS.tileRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WeightBar(
            threshold: 5,
            height: 16,
            segments: [
              WeightSegment(currentWeight: 47, targetWeight: 40),
              WeightSegment(currentWeight: 30, targetWeight: 30),
              WeightSegment(currentWeight: 23, targetWeight: 30),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Text(
                isKo ? '세로선이 목표 비중' : 'Lines are your targets',
                style: TextStyle(
                  color: context.onBrandSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '+7.0%p',
                style: TextStyle(
                  color: context.onBrandWarning,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2쪽 ① · 보유 종목 한 줄. 자산 화면의 행과 같은 모양.
class _HoldingDemo extends StatelessWidget {
  const _HoldingDemo();

  @override
  Widget build(BuildContext context) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    return _demoBox(
      context,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.chipKrBg,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(isKo ? 'KR' : 'US',
                style: TextStyle(
                    color: context.chipKrText,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isKo ? 'TIGER 미국S&P500' : 'VTI',
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(isKo ? '₩19,700 · 120주' : '\$268.40 · 120 sh',
                    style: TextStyle(
                        color: context.textTertiary, fontSize: 11)),
              ],
            ),
          ),
          Text(isKo ? '₩2,364,000' : '\$32,208',
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// 2쪽 ② · 목표 비중을 다 맞춘 상태. 벗어난 칸이 없어 전부 차분한 색이다.
class _TargetDemo extends StatelessWidget {
  const _TargetDemo();

  @override
  Widget build(BuildContext context) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    return _demoBox(
      context,
      child: Column(
        children: [
          const WeightBar(
            threshold: 0.5,
            height: 14,
            segments: [
              WeightSegment(currentWeight: 40, targetWeight: 40),
              WeightSegment(currentWeight: 30, targetWeight: 30),
              WeightSegment(currentWeight: 30, targetWeight: 30),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // 좁은 기기에서 칩을 밀어내지 않게 줄어들 수 있게 둔다.
              Flexible(
                child: Text('40% · 30% · 30%',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.subtleFill,
                  borderRadius: BorderRadius.circular(DS.chipRadius),
                ),
                child: Text(isKo ? '허용 ±0.5%p' : 'Tolerance ±0.5pp',
                    style: TextStyle(
                        color: context.brandOnLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2쪽 ③ · 조정 제안 한 줄. 제안 화면의 행과 같은 모양.
class _TradeDemo extends StatelessWidget {
  const _TradeDemo();

  @override
  Widget build(BuildContext context) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    Widget row(bool sell, String name, String qty, String amount) => Row(
          children: [
            Container(
              width: 32,
              padding: const EdgeInsets.symmetric(vertical: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sell ? context.pnlDownTint : context.pnlUpTint,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                sell ? (isKo ? '매도' : 'Sell') : (isKo ? '매수' : 'Buy'),
                style: TextStyle(
                    color: sell ? context.danger : context.brandOnLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(name,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Text(qty,
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3)),
          ],
        );

    return _demoBox(
      context,
      child: Column(
        children: [
          row(true, isKo ? 'TIGER 미국S&P500' : 'VTI',
              isKo ? '18주' : '18 sh', ''),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Divider(height: 1, color: context.dividerColor),
          ),
          row(false, isKo ? 'ACE KRX금현물' : 'GLD', isKo ? '42주' : '42 sh', ''),
        ],
      ),
    );
  }
}

Widget _demoBox(BuildContext context, {required Widget child}) => Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: context.rowBg,
        borderRadius: BorderRadius.circular(DS.tileRadius),
      ),
      child: child,
    );

/// 템플릿의 목표 비중을 한 줄 막대로.
///
/// 칸 너비가 목표 비중이다. 이모지 하나보다 「어떻게 나뉘는지」를 훨씬
/// 빨리 전하고, 앱 안에서 보게 될 막대와 같은 언어를 쓴다.
class AllocationBar extends StatelessWidget {
  /// 칸 너비가 될 목표 비중들.
  final List<double> weights;

  const AllocationBar({super.key, required this.weights});

  /// 칸 색. 브랜드 한 색의 농담으로만 간다 — 자산군마다 다른 색을 주면
  /// 그 색이 무슨 뜻인지 또 배워야 한다.
  static Color toneOf(BuildContext context, int i) {
    final tones = [
      context.brand,
      context.brandOnLight,
      context.weightOkFill,
      context.trackBg,
      context.disabledFill,
    ];
    return tones[i % tones.length];
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 10,
        child: Row(
          // **stretch가 없으면 막대가 통째로 사라진다.** Row의 기본값은
          // center라 자식에게 느슨한 높이를 준다. 자식 없는 ColoredBox는
          // 그럼 높이 0이 되는데, 예외도 경고도 안 난다.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < weights.length; i++)
              Expanded(
                flex: (weights[i] * 10).round(),
                child: ColoredBox(color: toneOf(context, i)),
              ),
          ],
        ),
      ),
    );
  }
}

// ══ 데이터 ══

class _Item {
  final String name;
  final String ticker;
  final String market;
  final bool isCash;
  final double weight;

  /// 템플릿 카드에 적을 짧은 이름. 종목 정식명은 카드에서 너무 길다.
  final String label;

  const _Item(this.name, this.ticker, this.market, this.isCash, this.weight,
      this.label);
}

class _Sample {
  final String name;
  final String desc;
  final List<_Item> items;

  /// 포트 기준 통화. **템플릿마다 다르다** — 국내 상장 ETF판은 원화다.
  /// 전에는 `build()`에 'USD'가 박혀 있어, 국내판을 담으면 `$0.00`이 떴다.
  final String currency;

  const _Sample({
    required this.name,
    required this.desc,
    required this.items,
    this.currency = 'USD',
  });

  Portfolio build(String pfId) => Portfolio(
        id: pfId,
        name: name,
        currency: currency,
        items: items
            .asMap()
            .entries
            .map((e) => PortfolioItem(
                  id: '${pfId}_i${e.key}',
                  name: e.value.name,
                  ticker: e.value.ticker,
                  market: e.value.market,
                  isCash: e.value.isCash,
                  targetWeight: e.value.weight,
                ))
            .toList(),
      );
}
