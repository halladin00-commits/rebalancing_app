import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../widgets/app_logo.dart';
import '../widgets/brand_header.dart';

/// 첫 실행 화면.
///
/// 1쪽은 스플래시와 같은 딥그린 한 판이라 앱이 켜지는 흐름이 끊기지 않고,
/// 2쪽은 크림 배경 + 딥그린 헤더로 실제 앱 화면을 미리 보여준다.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
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

  /// 시작 템플릿.
  ///
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
          emoji: '🌤️',
          name: '올웨더 포트폴리오',
          desc: '레이 달리오의 전천후 자산배분 · 국내 상장 ETF판',
          tags: [
            'S&P500 30%',
            '국고채30년 40%',
            '국고채10년 15%',
            '금 15%',
          ],
          currency: 'KRW',
          items: [
            _Item('TIGER 미국S&P500', '360750', 'KR', false, 30),
            _Item('KODEX 국고채30년액티브', '439870', 'KR', false, 40),
            _Item('ACE 국고채10년', '365780', 'KR', false, 15),
            // 원안은 금 7.5% + 원자재 7.5%다. 국내에는 광범위 원자재 ETF가
            // 없어(농산물·원유·구리 같은 단일 품목뿐) 실물자산 몫 15%를
            // 금현물 하나로 모았다. 선물 ETF로 쪼개면 롤오버 비용이 붙고
            // 첫 템플릿에 종목이 여섯 개가 된다. **바꿨다는 사실은 설명에 밝힌다.**
            _Item('ACE KRX금현물', '411060', 'KR', false, 15),
          ],
        ),
        const _Sample(
          emoji: '💎',
          name: '영구 포트폴리오',
          desc: '해리 브라운의 4자산 균형 배분 · 국내 상장 ETF판',
          tags: [
            'S&P500 25%',
            '국고채30년 25%',
            '금 25%',
            '현금 25%',
          ],
          currency: 'KRW',
          items: [
            _Item('TIGER 미국S&P500', '360750', 'KR', false, 25),
            _Item('KODEX 국고채30년액티브', '439870', 'KR', false, 25),
            _Item('ACE KRX금현물', '411060', 'KR', false, 25),
            _Item('현금', '', 'CASH', true, 25),
          ],
        ),
        const _Sample(
          emoji: '🌍',
          name: '글로벌 60/40',
          desc: '전통적 주식 60%, 채권 40% 배분 · 국내 상장 ETF판',
          tags: [
            'S&P500 40%',
            'MSCI선진국 20%',
            '종합채권 40%',
          ],
          currency: 'KRW',
          items: [
            _Item('TIGER 미국S&P500', '360750', 'KR', false, 40),
            _Item('KODEX MSCI선진국', '251350', 'KR', false, 20),
            _Item('KODEX 종합채권(AA-이상)액티브', '273130', 'KR', false, 40),
          ],
        ),
      ];

  /// 미국 상장 ETF판 (영어 사용자).
  List<_Sample> _usSamples() => [
        const _Sample(
          emoji: '🌤️',
          name: 'All Weather',
          desc: "Ray Dalio's all-weather allocation",
          tags: ['VTI 30%', 'TLT 40%', 'IEF 15%', 'GLD 7.5%', 'DJP 7.5%'],
          items: [
            _Item('VTI', 'VTI', 'US', false, 30),
            _Item('TLT', 'TLT', 'US', false, 40),
            _Item('IEF', 'IEF', 'US', false, 15),
            _Item('GLD', 'GLD', 'US', false, 7.5),
            _Item('DJP', 'DJP', 'US', false, 7.5),
          ],
        ),
        const _Sample(
          emoji: '💎',
          name: 'Permanent Portfolio',
          desc: "Harry Browne's 4-asset balance",
          tags: ['VTI 25%', 'TLT 25%', 'GLD 25%', 'Cash 25%'],
          items: [
            _Item('VTI', 'VTI', 'US', false, 25),
            _Item('TLT', 'TLT', 'US', false, 25),
            _Item('GLD', 'GLD', 'US', false, 25),
            _Item('Cash', '', 'CASH', true, 25),
          ],
        ),
        const _Sample(
          emoji: '🌍',
          name: 'Global 60/40',
          desc: 'Classic 60% stocks, 40% bonds',
          tags: ['VTI 40%', 'VEA 20%', 'BND 40%'],
          items: [
            _Item('VTI', 'VTI', 'US', false, 40),
            _Item('VEA', 'VEA', 'US', false, 20),
            _Item('BND', 'BND', 'US', false, 40),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isKo = context.watch<LocaleProvider>().locale.languageCode == 'ko';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) {
          _pageCtrl.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light, // Android
          statusBarBrightness: Brightness.dark, // iOS
        ),
        child: Scaffold(
          backgroundColor: context.scaffoldBg,
          body: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (p) => setState(() => _page = p),
            children: [
              _buildWelcome(context, isKo),
              _buildSamples(context, isKo),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1쪽: 환영 + 기능 소개 (딥그린 한 판) ──

  Widget _buildWelcome(BuildContext context, bool isKo) {
    return ColoredBox(
      color: context.appBarBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 32, 26, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLogo(iconSize: 28),
              const SizedBox(height: 34),
              Text(
                isKo ? '반갑습니다!' : 'Welcome!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isKo
                    ? '자산현황부터 리밸런싱 계산까지\n투자의 모든 단계를 한 앱에서'
                    : 'From portfolio overview to rebalancing\n— everything in one app',
                style: TextStyle(
                  color: context.onBrandSecondary,
                  fontSize: 14.5,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 40),
              _featureRow(
                context,
                Icons.pie_chart_outline,
                isKo ? '내 자산현황을 한눈에' : 'Portfolio overview at a glance',
                isKo
                    ? '보유 종목, 평가손익, 비중을 한 화면에서'
                    : 'Holdings, P&L, and weights all in one view',
              ),
              const SizedBox(height: 24),
              _featureRow(
                context,
                Icons.calculate_outlined,
                isKo ? '매수·매도 수량 자동 계산' : 'Auto buy/sell quantity',
                isKo
                    ? '목표 비중 입력만으로 수량까지 한번에'
                    : 'From target weights to exact quantities',
              ),
              const SizedBox(height: 24),
              _featureRow(
                context,
                Icons.trending_up,
                isKo ? '주가·환율 자동 조회' : 'Auto price & rate fetch',
                isKo
                    ? '새로고침 한 번으로\n현재가·환율 자동 업데이트'
                    : 'One tap refresh for\ncurrent prices & FX rate',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: DS.buttonHeight,
                child: ElevatedButton(
                  onPressed: () => _pageCtrl.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: context.brand,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DS.buttonRadius)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isKo ? '다음' : 'Next',
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(
      BuildContext context, IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(DS.tileRadius),
          ),
          child: Icon(icon, color: context.onBrandAccent, size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(desc,
                  style: TextStyle(
                      color: context.onBrandSecondary,
                      fontSize: 12.5,
                      height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }

  // ── 2쪽: 샘플 포트폴리오 선택 ──

  Widget _buildSamples(BuildContext context, bool isKo) {
    final samples = _getSamples(isKo);
    final n = _selected.length;

    return Column(
      children: [
        BrandHeader(
          title: isKo ? '샘플 포트폴리오' : 'Sample Portfolios',
          childPadding: const EdgeInsets.fromLTRB(22, 2, 22, 18),
          leading: IconButton(
            onPressed: () => _pageCtrl.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            tooltip: context.l10n.a11yBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          child: Text(
            isKo
                ? '관심 있는 템플릿을 선택하세요. 건너뛰어도 됩니다.'
                : 'Pick a template to get started — or skip.',
            style: TextStyle(
                color: context.onBrandSecondary,
                fontSize: DS.body,
                fontWeight: FontWeight.w500,
                height: 1.45),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            itemCount: samples.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (_, idx) => _sampleCard(context, idx, samples[idx]),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, 16 + MediaQuery.of(context).padding.bottom),
          child: SizedBox(
            width: double.infinity,
            height: DS.buttonHeight,
            child: ElevatedButton(
              onPressed: () => _start(isKo),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DS.buttonRadius)),
              ),
              child: Text(
                n > 0
                    ? (isKo
                        ? '$n개 샘플 추가 · 시작하기'
                        : 'Add $n template${n > 1 ? 's' : ''} & Start')
                    : (isKo ? '시작하기' : 'Get Started'),
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sampleCard(BuildContext context, int idx, _Sample s) {
    final sel = _selected.contains(idx);
    return GestureDetector(
      onTap: () =>
          setState(() => sel ? _selected.remove(idx) : _selected.add(idx)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? context.brandTint : context.cardBg,
          borderRadius: BorderRadius.circular(DS.listCardRadius),
          border: Border.all(
            color: sel ? context.brand : context.cardBorder,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.emoji, style: const TextStyle(fontSize: 25)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(s.desc,
                      style: TextStyle(
                          color: context.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: s.tags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: context.subtleFill,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(t,
                                  style: TextStyle(
                                      color: context.brandOnLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
      ),
    );
  }
}

// ── 데이터 클래스 ──

class _Item {
  final String name;
  final String ticker;
  final String market;
  final bool isCash;
  final double weight;
  const _Item(this.name, this.ticker, this.market, this.isCash, this.weight);
}

class _Sample {
  final String emoji;
  final String name;
  final String desc;
  final List<String> tags;
  final List<_Item> items;

  /// 포트 기준 통화. **템플릿마다 다르다** — 국내 상장 ETF판은 원화다.
  /// 전에는 `build()`에 'USD'가 박혀 있어, 국내판을 담으면 `$0.00`이 떴다.
  final String currency;

  const _Sample({
    required this.emoji,
    required this.name,
    required this.desc,
    required this.tags,
    required this.items,
    this.currency = 'USD',
  });

  Portfolio build(String pfId) => Portfolio(
        id: pfId,
        name: name,
        emoji: emoji,
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
