/// 한국어 조사 선택.
///
/// `TIGER 반도체이(가) 목표보다 많습니다` 처럼 두 형태를 나란히 쓰지 않기 위해,
/// 앞 글자의 받침을 보고 맞는 것 하나를 고른다.
///
/// 종목명은 한글·영문·숫자가 섞여 있으므로(`TIGER 200`, `SPY`, `SPDR`) 셋 다 다룬다.
/// 영문·숫자는 한국어로 읽었을 때의 끝소리를 기준으로 한다
/// (`SPY` → 에스피와이 → 받침 없음, `SPDR` → 에스피디알 → ㄹ 받침).
library;

/// 마지막 글자의 받침 종류. `으로`/`로`는 ㄹ 받침을 따로 구분해야 해서 셋으로 나눈다.
enum _Final { none, rieul, other }

/// 고를 수 있는 조사 쌍.
enum Josa {
  iGa('이', '가'),
  eunNeun('은', '는'),
  eulReul('을', '를'),
  gwaWa('과', '와'),

  /// `으로`/`로`. ㄹ 받침 뒤에서는 받침이 없을 때와 같이 `로`를 쓴다.
  euro('으로', '로');

  const Josa(this.afterFinal, this.afterVowel);

  /// 받침이 있을 때 쓰는 형태 (`이`, `은`, `을`, `과`, `으로`)
  final String afterFinal;

  /// 받침이 없을 때 쓰는 형태 (`가`, `는`, `를`, `와`, `로`)
  final String afterVowel;
}

/// 한글로 읽었을 때 ㄹ 받침으로 끝나는 숫자: 1(일) 7(칠) 8(팔)
const _digitRieul = {'1', '7', '8'};

/// 받침이 아예 없는 숫자: 2(이) 4(사) 5(오) 9(구)
/// 나머지 0(영) 3(삼) 6(육)은 ㄹ이 아닌 받침을 가진다.
const _digitNoFinal = {'2', '4', '5', '9'};

/// 알파벳 한 글자를 한국어로 읽었을 때 ㄹ 받침으로 끝나는 것: L(엘) R(알)
const _letterRieul = {'l', 'r'};

/// ㄹ이 아닌 받침으로 끝나는 알파벳: M(엠) N(엔)
/// 나머지는 모음으로 끝난다고 본다 (B 비, C 씨, K 케이, Y 와이 …).
const _letterOtherFinal = {'m', 'n'};

/// 조사 판단에 쓸 마지막 글자를 고른다.
///
/// `삼성전자(우)`, `'삼성전자'` 처럼 뒤에 괄호나 따옴표가 붙어도 소리는 그 앞
/// 글자에서 나므로, 글자·숫자가 나올 때까지 뒤에서부터 건너뛴다.
String? _lastSpokenChar(String name) {
  for (var i = name.length - 1; i >= 0; i--) {
    final c = name[i];
    final code = c.codeUnitAt(0);
    final isHangul = code >= 0xAC00 && code <= 0xD7A3;
    final isDigit = code >= 0x30 && code <= 0x39;
    final isLatin =
        (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
    if (isHangul || isDigit || isLatin) return c;
  }
  return null;
}

_Final _finalOf(String name) {
  final c = _lastSpokenChar(name);
  if (c == null) return _Final.none;

  final code = c.codeUnitAt(0);

  // 한글 음절: 종성 코드로 바로 판단한다. 8번이 ㄹ이다.
  if (code >= 0xAC00 && code <= 0xD7A3) {
    final jong = (code - 0xAC00) % 28;
    if (jong == 0) return _Final.none;
    return jong == 8 ? _Final.rieul : _Final.other;
  }

  if (code >= 0x30 && code <= 0x39) {
    if (_digitRieul.contains(c)) return _Final.rieul;
    return _digitNoFinal.contains(c) ? _Final.none : _Final.other;
  }

  final lower = c.toLowerCase();
  if (_letterRieul.contains(lower)) return _Final.rieul;
  if (_letterOtherFinal.contains(lower)) return _Final.other;
  return _Final.none;
}

/// [name] 뒤에 붙일 조사만 돌려준다. 이름은 붙이지 않는다.
String josaFor(String name, Josa josa) {
  final f = _finalOf(name);
  // `으로`만 ㄹ 받침을 받침 없음과 같이 취급한다 (`서울로`, `SPDR로`).
  if (josa == Josa.euro && f == _Final.rieul) return josa.afterVowel;
  return f == _Final.none ? josa.afterVowel : josa.afterFinal;
}

/// [name] 뒤에 맞는 조사를 붙여 돌려준다.
///
/// [korean]이 false면 (영어 화면) 이름을 그대로 돌려준다. 영어 문장에는 조사가
/// 없으므로, 같은 호출부에서 두 언어를 함께 다룰 수 있다.
String withJosa(String name, Josa josa, {bool korean = true}) =>
    korean ? '$name${josaFor(name, josa)}' : name;
