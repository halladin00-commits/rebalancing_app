import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class DisclaimerDialog extends StatefulWidget {
  /// true: 첫 실행 모드 (체크박스 + 다시 안 보기)
  /// false: 공지사항 메뉴에서 열기 (확인 버튼만)
  final bool isFirstRun;
  const DisclaimerDialog({super.key, this.isFirstRun = true});

  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final skip = prefs.getBool('disclaimer_skip') ?? false;
    if (skip) return;
    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const DisclaimerDialog(isFirstRun: true),
      );
    }
  }

  static Future<void> showAlways(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const DisclaimerDialog(isFirstRun: false),
    );
  }

  @override
  State<DisclaimerDialog> createState() => _DisclaimerDialogState();
}

class _DisclaimerDialogState extends State<DisclaimerDialog> {
  bool _checked = false;

  Future<void> _confirm() async {
    if (widget.isFirstRun && _checked) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('disclaimer_skip', true);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = !widget.isFirstRun || _checked;
    return AlertDialog(
      backgroundColor: context.cardBg,
      title: Text('서비스 이용 안내 및 면책고지',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section(context, '목적'),
                    _body(context,
                        '본 앱(Rebalancing)은 개인 투자자의 포트폴리오 리밸런싱 계산을 돕기 위한 참고용 도구입니다. 어떠한 경우에도 금융투자 조언, 투자 권유, 자산 운용 서비스를 제공하지 않습니다.'),
                    _section(context, '데이터 정확성'),
                    _body(context,
                        '앱이 제공하는 다음 정보는 외부 공개 API 및 데이터 소스를 기반으로 하며, 지연·오류·누락이 발생할 수 있습니다.\n\n• 종목 정보 (종목명, 티커, 시장 구분)\n• 실시간 주가 (Yahoo Finance 기반)\n• 실시간 환율 (공개 환율 API 기반)\n• ETF 분류 및 관련 정보\n• 리밸런싱 계산 결과 (수량, 비중, 잔여 현금 등)\n• 예상 수수료 계산값\n\n실제 시장 데이터 및 금융기관 정보와 다를 수 있으므로, 반드시 직접 확인하시기 바랍니다.'),
                    _section(context, '투자 손실 책임'),
                    _body(context,
                        '본 앱의 정보를 바탕으로 내린 투자 결정 및 그로 인한 손실·손해에 대해 개발자는 어떠한 법적 책임도 지지 않습니다. 모든 투자 결정은 사용자 본인의 판단과 책임 하에 이루어져야 합니다.'),
                    _section(context, '세금 및 법적 사항'),
                    _body(context,
                        '금융거래에 따른 세금 신고, 양도소득세, 금융소득 종합과세 등 법적 의무는 사용자가 직접 확인하고 이행해야 합니다. 본 앱은 세무·법률 조언을 제공하지 않습니다.'),
                    _section(context, '서비스 변경 및 중단'),
                    _body(context,
                        '앱의 기능, 데이터 소스, 서비스는 사전 고지 없이 변경되거나 중단될 수 있습니다.'),
                  ],
                ),
              ),
            ),
            if (widget.isFirstRun) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () => setState(() => _checked = !_checked),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _checked
                        ? const Color(0xFF1D4ED8).withValues(alpha: 0.15)
                        : context.rowBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _checked ? const Color(0xFF3B82F6) : context.borderColor,
                    ),
                  ),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _checked ? const Color(0xFF3B82F6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _checked ? const Color(0xFF3B82F6) : context.borderColor,
                          width: 2,
                        ),
                      ),
                      child: _checked
                          ? const Icon(Icons.check, color: Colors.white, size: 12)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '위 내용을 확인하였으며, 다음부터 이 안내를 표시하지 않습니다',
                        style: TextStyle(
                            fontSize: 13,
                            color: _checked
                                ? const Color(0xFF93C5FD)
                                : context.textSecondary),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canConfirm ? _confirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canConfirm ? const Color(0xFF3B82F6) : context.disabledFill,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              widget.isFirstRun ? '확인하고 시작하기' : '확인',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: canConfirm ? Colors.white : context.textHint,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3B82F6))),
      );

  Widget _body(BuildContext context, String text) => Text(
        text,
        style: TextStyle(fontSize: 12, color: context.textSecondary, height: 1.5),
      );
}
