import 'dart:ui' show Locale;

import 'strings_en.dart';
import 'strings_fr.dart';
import 'strings_ja.dart';
import 'strings_ko.dart';
import 'strings_zh.dart';

/// 앱이 지원하는 언어. 새 언어는 여기에 더하고 strings_xx.dart 를 만든다.
enum Lang { ko, en, ja, zh, fr }

extension LangInfo on Lang {
  String get code => name;

  /// 그 언어로 쓴 이름 (lang 명령어와 설정에 보인다)
  String get label => switch (this) {
        Lang.ko => '한국어',
        Lang.en => 'English',
        Lang.ja => '日本語',
        Lang.zh => '中文',
        Lang.fr => 'Français',
      };

  Locale get locale => Locale(name);
}

const _tables = <Lang, Map<String, String>>{
  Lang.ko: koStrings,
  Lang.en: enStrings,
  Lang.ja: jaStrings,
  Lang.zh: zhStrings,
  Lang.fr: frStrings,
};

/// 지금 쓰는 언어.
///
/// [pref] 는 사용자가 고른 값('auto' 또는 언어 코드)이고, 'auto' 면 폰 언어([device])를 따른다.
/// 폰이 지원하지 않는 언어면 영어.
class L10n {
  static const autoPref = 'auto';

  /// `lang` 명령어에서 쓸 수 있는 값
  static List<String> get prefs => [autoPref, for (final l in Lang.values) l.code];

  static String pref = autoPref;
  static Lang device = Lang.en;

  static Lang get current => langFromCode(pref) ?? device;

  static bool isPref(String value) => value == autoPref || langFromCode(value) != null;

  static Lang? langFromCode(String code) {
    for (final l in Lang.values) {
      if (l.code == code) return l;
    }
    return null;
  }

  static Lang fromLocale(Locale locale) =>
      langFromCode(locale.languageCode) ?? Lang.en;

  /// 폰 언어가 바뀌었을 때(또는 시작할 때) 부른다.
  static void syncDevice(Locale locale) => device = fromLocale(locale);

  /// 저장된 값이 이상하면 auto.
  static String cleanPref(String? value) => value != null && isPref(value) ? value : autoPref;
}

/// 문구 가져오기. `tr('ok.add', {'n': '#03'})` → `+ #03 추가됨`
///
/// 그 언어에 키가 없으면 영어, 그래도 없으면 한국어, 마지막엔 키 자체를 돌려준다.
String tr(String key, [Map<String, Object?>? args]) => trIn(L10n.current, key, args);

String trIn(Lang lang, String key, [Map<String, Object?>? args]) {
  var s = _tables[lang]![key] ?? enStrings[key] ?? koStrings[key] ?? key;
  if (args != null) {
    for (final e in args.entries) {
      s = s.replaceAll('{${e.key}}', '${e.value}');
    }
  }
  return s;
}

bool trHas(String key) => koStrings.containsKey(key);

/// 요일 이름 (월요일 = 1)
String weekdayName(int weekday) => tr('wd.$weekday');

/// 테스트용: 모든 언어의 표
Map<Lang, Map<String, String>> get l10nTables => _tables;
