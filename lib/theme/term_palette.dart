import 'package:flutter/widgets.dart';

/// 터미널 색. 폰이 다크 모드면 cmd, 라이트 모드면 종이에 출력한 cmd.
class TermPalette {
  const TermPalette({
    required this.bg,
    required this.bar,
    required this.panel,
    required this.fg,
    required this.hi,
    required this.dim,
    required this.ok,
    required this.tag,
    required this.cmd,
    required this.warn,
    required this.line,
    required this.acc,
    this.isLight = false,
  });

  final bool isLight;

  /// 배경
  final Color bg;

  /// 상단 바, 하단 입력 영역
  final Color bar;

  /// 살짝 떠 있는 영역
  final Color panel;

  /// 기본 글자
  final Color fg;

  /// 강조 글자
  final Color hi;

  /// 보조 글자 (배경 대비 4.5:1 이상)
  final Color dim;

  /// 성공
  final Color ok;

  /// .LOG, 찾은 말
  final Color tag;

  /// 명령어
  final Color cmd;

  /// 에러
  final Color warn;

  /// 구분선
  final Color line;

  /// notepad.exe 색 (커서, 잠금)
  final Color acc;

  static const dark = TermPalette(
    bg: Color(0xFF0C0C0C),
    bar: Color(0xFF1A1A1A),
    panel: Color(0xFF121212),
    fg: Color(0xFFCCCCCC),
    hi: Color(0xFFF2F2F2),
    dim: Color(0xFF8A8A8A),
    ok: Color(0xFF16C60C),
    tag: Color(0xFFF9F1A5),
    cmd: Color(0xFF61D6D6),
    warn: Color(0xFFE74856),
    line: Color(0xFF2A2A2A),
    acc: Color(0xFF6CA6FF),
  );

  static const light = TermPalette(
    isLight: true,
    bg: Color(0xFFF5F2E8),
    bar: Color(0xFFE8E4D6),
    panel: Color(0xFFEDE9DC),
    fg: Color(0xFF2B2B2B),
    hi: Color(0xFF111111),
    dim: Color(0xFF6B6B6B),
    ok: Color(0xFF0B7A0B),
    tag: Color(0xFF7A5F00),
    cmd: Color(0xFF0B6E8A),
    warn: Color(0xFFC0282F),
    line: Color(0xFFD6D1C2),
    acc: Color(0xFF1F5FD1),
  );

  static TermPalette of(Brightness b) => b == Brightness.light ? light : dark;
}

const monoFamily = 'JetBrainsMono';
const monoFallback = ['NanumGothicCoding'];

/// 앱 전체에서 쓰는 고정폭 글꼴 스타일. 한글은 나눔고딕코딩으로 대체된다.
TextStyle termStyle(
  Color color, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
  TextDecoration? decoration,
  double height = 1.5,
}) =>
    TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: monoFallback,
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      decoration: decoration,
      decorationColor: color,
    );
