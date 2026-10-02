import 'package:flutter_test/flutter_test.dart';
import 'package:notepad_exe/logic/commands.dart';
import 'package:notepad_exe/logic/notes.dart';
import 'package:notepad_exe/widget_sync.dart';

void main() {
  final now = DateTime(2026, 10, 2, 16, 52);
  NotepadData run(NotepadData d, String s, {DateTime? at}) => runCommand(d, s, at ?? now, pro: true).data;

  test('위젯 JSON: 최근 메모 · 목록, 잠긴 메모는 없다', () {
    var d = run(NotepadData.empty(), 'echo 우유 2개 >> 장보기', at: DateTime(2026, 10, 1));
    d = run(d, 'echo 두부 >> 장보기', at: DateTime(2026, 10, 1));
    d = run(d, 'echo 엄마 스카프 >> 선물');
    d = run(d, 'attrib +h 선물');
    final j = widgetSnapshot(d, now, pro: true);
    expect(j['pro'], isTrue);
    expect(j['count'], 1);
    final note = j['note'] as Map;
    expect(note['name'], '장보기.txt');
    expect(note['lines'], ['우유 2개', '두부']);
    expect(note['pinned'], isFalse);
    expect((j['recent'] as List).map((r) => r['name']), ['장보기.txt']);
    expect(j.toString().contains('선물'), isFalse);
    expect(j.toString().contains('스카프'), isFalse);
  });

  test('pin 한 메모가 위젯에', () {
    var d = run(NotepadData.empty(), 'echo a >> 하나', at: DateTime(2026, 10, 1));
    d = run(d, 'echo b >> 둘');
    d = run(d, 'pin 하나');
    final j = widgetSnapshot(d, now);
    expect((j['note'] as Map)['name'], '하나.txt');
    expect((j['note'] as Map)['pinned'], isTrue);
  });

  test('위젯에서 온 주소', () {
    expect(WidgetRequest.parse(Uri.parse('notepadexe://open?id=3&homeWidget'))!.noteId, 3);
    expect(WidgetRequest.parse(Uri.parse('notepadexe://new?homeWidget'))!.noteId, isNull);
    expect(WidgetRequest.parse(Uri.parse('other://open?id=3')), isNull);
    expect(WidgetRequest.parse(null), isNull);
  });

  test('upgrade · restore 는 PRO 화면으로', () {
    final d = NotepadData.empty();
    expect(runCommand(d, 'upgrade', now).route, 'pro');
    expect(runCommand(d, 'restore', now).route, 'restore');
  });
}
