import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../widgets/app_logo.dart';

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

  List<_Sample> _getSamples(bool isKo) => [
        _Sample(
          emoji: '🌤️',
          name: isKo ? '올웨더 포트폴리오' : 'All Weather',
          desc: isKo
              ? '레이 달리오의 전천후 자산배분'
              : "Ray Dalio's all-weather allocation",
          tags: const ['VTI 30%', 'TLT 40%', 'IEF 15%', 'GLD 7.5%', 'DJP 7.5%'],
          color: const Color(0xFF3B82F6),
          items: [
            const _Item('VTI', 'VTI', 'US', false, 30),
            const _Item('TLT', 'TLT', 'US', false, 40),
            const _Item('IEF', 'IEF', 'US', false, 15),
            const _Item('GLD', 'GLD', 'US', false, 7.5),
            const _Item('DJP', 'DJP', 'US', false, 7.5),
          ],
        ),
        _Sample(
          emoji: '💎',
          name: isKo ? '영구 포트폴리오' : 'Permanent Portfolio',
          desc: isKo
              ? '해리 브라운의 4자산 균형 배분'
              : "Harry Browne's 4-asset balance",
          tags: ['VTI 25%', 'TLT 25%', 'GLD 25%', isKo ? '현금 25%' : 'Cash 25%'],
          color: const Color(0xFF8B5CF6),
          items: [
            const _Item('VTI', 'VTI', 'US', false, 25),
            const _Item('TLT', 'TLT', 'US', false, 25),
            const _Item('GLD', 'GLD', 'US', false, 25),
            _Item(isKo ? '현금' : 'Cash', '', 'CASH', true, 25),
          ],
        ),
        _Sample(
          emoji: '🌍',
          name: isKo ? '글로벌 60/40' : 'Global 60/40',
          desc: isKo
              ? '전통적 주식 60%, 채권 40% 배분'
              : 'Classic 60% stocks, 40% bonds',
          tags: const ['VTI 40%', 'VEA 20%', 'BND 40%'],
          color: const Color(0xFF22C55E),
          items: [
            const _Item('VTI', 'VTI', 'US', false, 40),
            const _Item('VEA', 'VEA', 'US', false, 20),
            const _Item('BND', 'BND', 'US', false, 40),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isKo =
        context.watch<LocaleProvider>().locale.languageCode == 'ko';
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
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (p) => setState(() => _page = p),
          children: [
            _buildPage1(isKo),
            _buildPage2(isKo),
          ],
        ),
      ),
    );
  }

  // ── 페이지 1: 환영 + 기능 소개 ──

  Widget _buildPage1(bool isKo) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppLogo(iconSize: 30),
            const SizedBox(height: 36),
            Text(
              isKo ? '반갑습니다!' : 'Welcome!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isKo
                  ? '자산현황부터 리밸런싱 계산까지\n투자의 모든 단계를 한 앱에서'
                  : 'From portfolio overview to rebalancing\n— everything in one app',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 40),
            _featureRow(
              Icons.pie_chart_outline,
              const Color(0xFF3B82F6),
              isKo ? '내 자산현황을 한눈에' : 'Portfolio overview at a glance',
              isKo
                  ? '보유 종목, 평가손익, 비중을 한 화면에서'
                  : 'Holdings, P&L, and weights all in one view',
            ),
            const SizedBox(height: 22),
            _featureRow(
              Icons.calculate_outlined,
              const Color(0xFF22C55E),
              isKo ? '매수·매도 수량 자동 계산' : 'Auto buy/sell quantity',
              isKo
                  ? '목표 비중 입력만으로 수량까지 한번에'
                  : 'From target weights to exact quantities',
            ),
            const SizedBox(height: 22),
            _featureRow(
              Icons.trending_up,
              const Color(0xFFF59E0B),
              isKo ? '주가·환율 자동 조회' : 'Auto price & rate fetch',
              isKo
                  ? '새로고침 한 번으로\n현재가·환율 자동 업데이트'
                  : 'One tap refresh for\ncurrent prices & FX rate',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _pageCtrl.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isKo ? '다음' : 'Next',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
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
    );
  }

  Widget _featureRow(
      IconData icon, Color color, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(desc,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  // ── 페이지 2: 샘플 포트폴리오 선택 ──

  Widget _buildPage2(bool isKo) {
    final samples = _getSamples(isKo);
    final n = _selected.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconButton(
                onPressed: () => _pageCtrl.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ]),
            Text(
              isKo ? '샘플 포트폴리오' : 'Sample Portfolios',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              isKo
                  ? '관심 있는 템플릿을 선택하세요 (건너뛰기 가능)'
                  : 'Pick a template to get started (optional)',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.separated(
                itemCount: samples.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, idx) => _sampleCard(idx, samples[idx]),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _start(isKo),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  n > 0
                      ? (isKo ? '$n개 샘플 추가 · 시작하기' : 'Add $n template${n > 1 ? 's' : ''} & Start')
                      : (isKo ? '시작하기' : 'Get Started'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sampleCard(int idx, _Sample s) {
    final sel = _selected.contains(idx);
    return GestureDetector(
      onTap: () => setState(
          () => sel ? _selected.remove(idx) : _selected.add(idx)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel
              ? s.color.withValues(alpha: 0.1)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel ? s.color : const Color(0xFF334155),
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(s.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(s.desc,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 3,
                    children: s.tags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: s.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(t,
                                  style: TextStyle(
                                      color: s.color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
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
                color: sel ? s.color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: sel ? s.color : const Color(0xFF475569),
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
  final Color color;
  final List<_Item> items;

  const _Sample({
    required this.emoji,
    required this.name,
    required this.desc,
    required this.tags,
    required this.color,
    required this.items,
  });

  Portfolio build(String pfId) => Portfolio(
        id: pfId,
        name: name,
        emoji: emoji,
        currency: 'USD',
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
