import 'package:flutter_test/flutter_test.dart';
import 'package:notepad_exe/l10n/l10n.dart';
import 'package:notepad_exe/logic/commands.dart';
import 'package:notepad_exe/logic/notes.dart';
import 'package:notepad_exe/widget_sync.dart';

Set<String> _slots(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

void main() {
  tearDown(() => L10n.pref = L10n.autoPref);

  test('모든 언어에 같은 키가 있다', () {
    final tables = l10nTables;
    final base = tables[Lang.ko]!.keys.toSet();
    for (final e in tables.entries) {
      expect(e.value.keys.toSet().difference(base), isEmpty, reason: '${e.key} 에만 있는 키');
      expect(base.difference(e.value.keys.toSet()), isEmpty, reason: '${e.key} 에 없는 키');
    }
  });

  test('{자리표시} 가 언어마다 같다', () {
    final ko = l10nTables[Lang.ko]!;
    for (final e in l10nTables.entries) {
      for (final k in ko.keys) {
        expect(_slots(e.value[k]!), _slots(ko[k]!), reason: '${e.key} · $k');
      }
    }
  });

  test('lang 명령: 바꾸면 바로 그 언어로 답한다', () {
    L10n.pref = 'ko';
    final r = runCommand(NotepadData.empty(), 'lang en', DateTime(2026, 10, 2, 16, 52));
    expect(r.data.lang, 'en');
    expect(r.lines.length, 2);
  });

  test('위젯 문구가 현재 언어로 나간다', () {
    final d = NotepadData.empty();
    L10n.pref = 'en';
    final en = widgetSnapshot(d, DateTime(2026, 10, 2))['s'] as Map;
    L10n.pref = 'ja';
    final ja = widgetSnapshot(d, DateTime(2026, 10, 2))['s'] as Map;
    expect(en.keys.toSet(), widgetStringKeys.toSet());
    expect(en['w.nofiles'], isNot(ja['w.nofiles']));
  });
}
