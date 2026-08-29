import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../theme/design_system.dart';

/// 포트폴리오 만들기 · 이름 변경 (시안 v13c).
///
/// 시안의 `보유 입력 방식`(거래 내역 / 현재 보유만) 세그먼트는 뺐다 —
/// 앱에 그런 구분이 없다. 종목마다 거래를 넣든 수량만 넣든 지금도 둘 다 된다.
class PortfolioFormScreen extends StatefulWidget {
  final String? initialName;
  final String? initialEmoji;
  final bool isEdit;

  /// 저장 후 호출. 새로 만들었으면 곧바로 종목을 담게 할 수 있다.
  final void Function(String name, String emoji) onSave;

  /// 만든 뒤 파일 올리기로 가는 경우 (시안 v17d의 `파일로 시작`).
  /// 안내와 버튼 문구가 실제로 가는 곳과 달라지면 안 된다.
  final bool uploadNext;

  const PortfolioFormScreen({
    super.key,
    this.uploadNext = false,
    this.initialName,
    this.initialEmoji,
    this.isEdit = false,
    required this.onSave,
  });

  @override
  State<PortfolioFormScreen> createState() => _PortfolioFormScreenState();
}

const _emojis = [
  '📈', '📉', '💰', '💵', '💴', '💶', '💷', '🪙', '💎', '🏦',
  '📊', '🔖', '🎯', '⭐', '🚀', '🌟', '💹', '🏠', '🛢️', '⚡',
];

/// 이름 길이 상한. 목록에서 한 줄에 들어가야 한다.
const _maxNameLength = 20;

class _PortfolioFormScreenState extends State<PortfolioFormScreen> {
  late final TextEditingController _nameCtl;
  late String _emoji;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.initialName ?? '');
    _emoji = widget.initialEmoji ?? '📈';
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = _nameCtl.text.trim();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(children: [
        _buildHeader(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              _buildNameField(context),
              const SizedBox(height: 18),
              Text(l10n.chooseEmoji,
                  style: TextStyle(
                      fontSize: DS.sectionTitle,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: context.textPrimary)),
              const SizedBox(height: 10),
              _buildEmojiGrid(context),
              const SizedBox(height: 18),
              // 만들자마자 어디로 가는지 미리 말해준다
              if (!widget.isEdit) ...[
                _hint(context, Icons.balance, l10n.hintTargetsInRebalanceTab),
                const SizedBox(height: 8),
                _hint(context, Icons.lightbulb_outline, widget.uploadNext ? l10n.hintThenUpload : l10n.hintThenAddStocks),
              ],
            ],
          ),
        ),
        _buildCta(context, name),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = context.l10n;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: context.appBarBg,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 52,
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                    widget.isEdit
                        ? l10n.renamePortfolio
                        : l10n.addPortfolioTitle,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: Colors.white)),
              ),
              const SizedBox(width: 14),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField(BuildContext context) {
    final l10n = context.l10n;
    final len = _nameCtl.text.characters.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.tileRadius),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(l10n.portfolioNameLabel,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary)),
          const Spacer(),
          Text('$len/$_maxNameLength',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: len >= _maxNameLength
                      ? context.warningText
                      : context.textTertiary)),
        ]),
        const SizedBox(height: 4),
        TextField(
          controller: _nameCtl,
          autofocus: !widget.isEdit,
          maxLength: _maxNameLength,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: context.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            hintText: l10n.portfolioNameHint,
            hintStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.textHint),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmojiGrid(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.tileRadius),
        border: Border.all(color: context.cardBorder),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final e in _emojis)
            GestureDetector(
              onTap: () => setState(() => _emoji = e),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _emoji == e ? context.brandTint : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: _emoji == e ? context.brand : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(e, style: const TextStyle(fontSize: 21)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hint(BuildContext context, IconData icon, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 15, color: context.textTertiary),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.55,
                color: context.textSecondary)),
      ),
    ]);
  }

  Widget _buildCta(BuildContext context, String name) {
    final l10n = context.l10n;
    return Container(
      color: context.scaffoldBg,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: DS.buttonHeight,
        child: ElevatedButton(
          onPressed: name.isEmpty
              ? null
              : () {
                  widget.onSave(name, _emoji);
                  Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: context.brand,
            foregroundColor: Colors.white,
            disabledBackgroundColor: context.disabledFill,
            disabledForegroundColor: context.textDisabled,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DS.buttonRadius)),
          ),
          child: Text(
              widget.isEdit ? l10n.saveChanges : widget.uploadNext ? l10n.createAndUpload : l10n.createAndAddStocks,
              style:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
