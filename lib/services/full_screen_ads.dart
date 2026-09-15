import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';

/// 앱을 켤 때 한 번 뜨는 전면 광고.
///
/// 전면 광고(Interstitial)는 넣었다 뺐다. 띄울 만한 자리가 한 달에 몇 번 안
/// 열려서, 얻는 것에 비해 자리가 비쌌다. 앱 오프닝만 남긴다 — 켤 때마다
/// 한 번이라 노출이 훨씬 많고, 닫기 버튼이 바로 있어 기다리게 하지 않는다.
///
/// **미리 받아 둔다.** 켠 다음에 받기 시작하면 몇 초 뒤에야 뜨는데, 그때는
/// 사용자가 이미 화면을 쓰고 있다. 하던 일을 끊는 광고가 되어 가장 나쁘다.
/// 스플래시가 떠 있는 동안 받아 두고, 준비되면 그 자리에서 띄운다.
class FullScreenAds {
  FullScreenAds._();

  /// 받아 놓은 광고. 띄우면 비운다.
  static AppOpenAd? _cached;
  static bool _loading = false;
  static bool _showing = false;

  /// 이번에 켠 뒤로 이미 띄웠는가. 한 번만 띄운다.
  static bool _shownThisLaunch = false;

  static bool get isReady => _cached != null;

  /// 받아 두기만 한다. 앱을 켜자마자 부른다.
  static void preload() {
    if (_cached != null || _loading) return;
    _loading = true;
    AppOpenAd.load(
      adUnitId: AdService.appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _cached = ad;
          _loadedAt = DateTime.now();
          // 기다리던 중이었으면 그 자리에서 띄운다.
          final until = _wantUntil;
          if (until != null && !_touched && DateTime.now().isBefore(until)) {
            _wantUntil = null;
            showIfReady();
          }
        },
        onAdFailedToLoad: (_) {
          _loading = false;
        },
      ),
    );
  }

  // ── 앱을 다시 앞으로 불러올 때 ──

  /// 이만큼 넘게 자리를 비웠다 돌아오면 「새로 켠 것」으로 본다.
  ///
  /// **이 앱은 증권사 앱과 번갈아 쓴다.** 조정 제안을 보고 넘어가 주문을 내고
  /// 돌아오는 게 기본 동선인데, 그 왕복마다 광고가 뜨면 하던 일을 끊는다.
  ///
  /// **1시간인 이유** — 자연스러운 방문(아침·장마감·저녁)은 원래 몇 시간씩
  /// 벌어져 있어서, 30분이든 2시간이든 평상시 노출 수는 거의 같다. 이 기준이
  /// 실제로 하는 일은 **증권사 왕복을 걸러내는 것**뿐이다.
  ///
  /// 그런데 주문이 열 건쯤 되는 리밸런싱은 30분을 넘긴다. 그러면 일을 막
  /// 끝내고 확인하러 돌아온 바로 그 순간에 광고가 뜬다 — 가장 나쁜 때다.
  /// 1시간으로 두면 노출은 사실상 그대로고 그 순간만 없어진다.
  static const awayEnough = Duration(
      seconds: int.fromEnvironment('AD_AWAY_SECONDS', defaultValue: 60 * 60));

  /// 켠 직후 광고를 기다려 주는 시간.
  ///
  /// 켤 때 한 번만 보고 말면 **사실상 한 번도 안 뜬다** — 동의 확인 ·
  /// SDK 시작 · 광고 요청까지 망 왕복이 여러 번이라, 보는 시점(첫 프레임
  /// 직후)에는 늘 아직 안 와 있다.
  ///
  /// 길게 두되 **손이 닿으면 그 자리에서 접는다**([noteUserTouch]).
  /// 이미 화면을 쓰고 있는 사람에게 튀어나오는 광고가 가장 나쁘다.
  static const _grace = Duration(
      seconds: int.fromEnvironment('AD_GRACE_SECONDS', defaultValue: 5));

  /// 이 시각 전에 광고가 오면 띄운다. 지나면 그냥 받아만 둔다.
  static DateTime? _wantUntil;

  /// 기다리기 시작한 뒤로 화면에 손이 닿았는가.
  ///
  /// **닿았으면 안 띄운다.** 앱을 열자마자 뜨는 광고와, 뭔가 누르는 도중에
  /// 튀어나오는 광고는 전혀 다른 것이다. 뒤엣것은 하던 일을 끊는다.
  static bool _touched = false;

  /// 화면에 손이 닿았다고 알린다. 앱 뿌리에서 부른다.
  static void noteUserTouch() => _touched = true;

  // ── 하루 한도 ──

  /// 하루에 띄울 수 있는 앱 오프닝 광고 수.
  ///
  /// **기준 시간만으로는 최악을 못 막는다.** 시장이 출렁이는 날엔 하루에
  /// 열 번도 여는데, 그런 날은 방문 간격이 벌어져 있어도 대여섯 번 보게
  /// 된다. 정작 자주 들여다보는 날이 가장 불안한 날이고, 그런 날 광고를
  /// 다섯 번 보여주면 앱을 지운다.
  ///
  /// [awayEnough]가 **평상시 모양**을 정한다면, 이 숫자는 **최악을 자른다.**
  static const dailyCap = int.fromEnvironment('AD_DAILY_CAP', defaultValue: 3);

  static const _keyCount = 'appopen_count';
  static const _keyDay = 'appopen_day';

  /// 오늘 몇 번 띄웠나. 앱을 껐다 켜도 이어지도록 저장한다 —
  /// **메모리에만 두면 껐다 켤 때마다 한도가 되살아난다.**
  static int _shownToday = 0;
  static String _today = '';

  static String _dayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// 저장해 둔 오늘치를 읽어 온다. 날이 바뀌었으면 0부터.
  static Future<void> _loadQuota() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyDay) ?? '';
    _today = _dayKey();
    _shownToday = saved == _today ? (prefs.getInt(_keyCount) ?? 0) : 0;
  }

  static Future<void> _noteShown() async {
    // 날이 바뀌었으면 여기서도 0으로 되돌린다 — 앱을 안 끄고 자정을 넘기면
    // [_loadQuota]가 다시 불릴 일이 없다.
    final day = _dayKey();
    if (day != _today) {
      _today = day;
      _shownToday = 0;
    }
    _shownToday++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDay, _today);
    await prefs.setInt(_keyCount, _shownToday);
  }

  static bool get _quotaLeft =>
      _dayKey() != _today || _shownToday < dailyCap;

  /// 구글은 받아 둔 앱 오프닝 광고를 4시간까지만 유효하다고 본다.
  static const _adLifetime = Duration(hours: 4);

  static DateTime? _loadedAt;
  static DateTime? _wentAway;
  static StreamSubscription<AppState>? _appState;

  /// 앞으로 돌아올 때 광고를 띄우기 시작한다.
  ///
  /// **깔고 처음 여는 날에는 부르지 않는다.** 그날은 온보딩을 막 지난
  /// 참이라, 잠깐 나갔다 와도 광고를 보여줄 때가 아니다.
  static void armForegroundShows() {
    if (_appState != null) return;
    AppStateEventNotifier.startListening();
    _appState = AppStateEventNotifier.appStateStream.listen((state) {
      if (state == AppState.background) {
        _wentAway = DateTime.now();
        return;
      }
      final away = _wentAway;
      _wentAway = null;
      if (away == null) return;
      if (DateTime.now().difference(away) < awayEnough) return;

      // 새 세션으로 보므로 「이번에 이미 띄웠다」를 푼다.
      _shownThisLaunch = false;
      unawaited(showWhenReady());
    });
  }

  /// 너무 오래 들고 있던 광고는 버린다.
  static void _dropIfStale() {
    final at = _loadedAt;
    if (at == null) return;
    if (DateTime.now().difference(at) < _adLifetime) return;
    _cached?.dispose();
    _cached = null;
    _loadedAt = null;
  }

  /// 있으면 지금, 없으면 **짧게 기다렸다가** 띄운다.
  ///
  /// [showIfReady]만 쓰면 사실상 한 번도 안 뜬다 — 켠 직후에 한 번 보는데
  /// 그때는 광고가 아직 안 와 있고, 그러면 다시 안 본다. 그렇다고 끝까지
  /// 기다리면 한참 뒤에 튀어나와 하던 일을 끊는다.
  ///
  /// [_grace]만큼만 문을 열어 둔다. 그 안에 오면 띄우고, 늦으면 다음을
  /// 위해 받아만 둔다.
  static Future<void> showWhenReady() async {
    // 오늘 몇 번 띄웠는지 먼저 읽는다. 기다리는 건 이 한 번뿐이고,
    // 광고는 어차피 뒤에 온다.
    await _loadQuota();
    if (!_quotaLeft) return;
    _dropIfStale();
    if (_cached != null) {
      showIfReady();
      return;
    }
    _touched = false;
    _wantUntil = DateTime.now().add(_grace);
    preload();
  }

  /// 받아 둔 게 있으면 띄운다. 없으면 아무것도 안 한다 — **기다리지 않는다.**
  static void showIfReady() {
    _dropIfStale();
    final ad = _cached;
    if (ad == null || _showing || _shownThisLaunch) return;
    // **여기서도 한 번 더 본다.** 받아 오는 사이에 한도가 찼을 수 있고,
    // 이 함수는 [showWhenReady]를 거치지 않고 불리기도 한다.
    if (!_quotaLeft) return;
    _cached = null;
    _showing = true;
    _shownThisLaunch = true;
    unawaited(_noteShown());
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _showing = false;
        ad.dispose();
        // **다음 것을 미리 받아 둔다.** 안 그러면 다시 돌아왔을 때 받아 둔
        // 게 없어서, 그 자리에서는 못 띄우고 또 그다음을 기약하게 된다.
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        _showing = false;
        ad.dispose();
        preload();
      },
    );
    ad.show();
  }
}
