import 'package:flutter_test/flutter_test.dart';
import 'package:notepad_exe/logic/commands.dart';
import 'package:notepad_exe/logic/notes.dart';

void main() {
  final now = DateTime(2026, 10, 2, 16, 52);
  CommandResult go(NotepadData d, String s, {bool pro = false, int? pending}) =>
      runCommand(d, s, now, pro: pro, pendingDelete: pending);
  NotepadData run(NotepadData d, String s, {bool pro = false}) => go(d, s, pro: pro).data;

  test('이름: .txt 붙이기 · 쓸 수 없는 글자', () {
    expect(normalizeName('장보기'), '장보기.txt');
    expect(normalizeName('"소설 아이디어"'), '소설 아이디어.txt');
    expect(normalizeName('todo.md'), 'todo.md');
    expect(normalizeName('a/b'), isNull);
    expect(normalizeName('왜?'), isNull);
    expect(normalizeName('   '), isNull);
  });

  test('시간 모양: 옛 메모장과 같게', () {
    expect(logStamp(DateTime(2026, 10, 2, 16, 52)), '오후 4:52 2026-10-02');
    expect(logStamp(DateTime(2026, 10, 2, 0, 5)), '오전 12:05 2026-10-02');
    expect(logStamp(DateTime(2026, 10, 2, 12, 0)), '오후 12:00 2026-10-02');
    expect(dirTime(DateTime(2026, 9, 3, 7, 4)), '09-03 07:04');
  });

  test('edit: 없으면 만들고 열기, 있으면 그냥 열기', () {
    var d = NotepadData.empty();
    final r = go(d, 'edit 장보기');
    expect(r.route, 'edit');
    expect(r.data.notes.single.name, '장보기.txt');
    d = r.data;
    final again = go(d, 'edit 장보기.TXT');
    expect(again.route, 'edit');
    expect(again.noteId, r.noteId);
    expect(again.data.notes, hasLength(1));
    expect(go(d, 'edit').lines.last.kind, LogKind.info);
    expect(go(d, 'edit a:b').lines[1].kind, LogKind.err);
  });

  test('echo >> 는 끝에 한 줄, > 는 새로 쓰기, type 으로 보기', () {
    var d = run(NotepadData.empty(), 'echo 우유 2개 >> 장보기');
    d = run(d, 'echo 두부 >> 장보기');
    expect(d.byName('장보기')!.text, '우유 2개\n두부');
    final t = go(d, 'type 장보기');
    expect(t.lines.skip(1).map((l) => l.text), ['우유 2개', '두부']);
    d = run(d, 'echo 대파 > 장보기');
    expect(d.byName('장보기')!.text, '대파');
    expect(go(d, 'echo 안녕').lines.last.text, '안녕');
    expect(go(d, 'type 없는거').lines.last.kind, LogKind.err);
  });

  test('find: 모든 메모에서, 잠긴 메모는 빼고', () {
    var d = run(NotepadData.empty(), 'echo 우유 2개 >> 장보기');
    d = run(d, 'echo 저지방 우유 >> 마트');
    d = run(d, 'echo 우유 비밀 >> 비밀');
    d = run(d, 'attrib +h 비밀', pro: true);
    final r = go(d, 'find 우유');
    final texts = r.lines.map((l) => l.text).toList();
    expect(texts, contains('---------- 장보기.txt'));
    expect(texts, contains('---------- 마트.txt'));
    expect(texts.any((t) => t.contains('비밀')), isFalse);
    expect(texts.last, '2줄 찾음');
    expect(go(d, 'find 없음').lines.last.text, contains('찾지 못했어요'));
  });

  test('ren: 따옴표 · 같은 이름', () {
    var d = run(NotepadData.empty(), 'edit 소설 아이디어');
    d = run(d, 'edit 마트');
    d = run(d, 'ren "소설 아이디어" 소설');
    expect(d.byName('소설'), isNotNull);
    expect(go(d, 'ren 소설 마트').lines[1].text, contains('이미 있습니다'));
    expect(go(d, 'ren 하나').lines[1].kind, LogKind.err);
  });

  test('del 은 (Y/N) 로 한 번 더 묻는다', () {
    var d = run(NotepadData.empty(), 'edit 장보기');
    final ask = go(d, 'del 장보기');
    expect(ask.askDelete, d.notes.single.id);
    expect(ask.data.notes, hasLength(1));
    expect(go(d, 'n', pending: ask.askDelete).data.notes, hasLength(1));
    d = go(d, 'Y', pending: ask.askDelete).data;
    expect(d.notes, isEmpty);
  });

  test('attrib +h 는 PRO, 잠긴 메모는 type · del · ren · 위젯 안 됨', () {
    var d = run(NotepadData.empty(), 'echo 엄마 스카프 >> 선물');
    final free = go(d, 'attrib +h 선물');
    expect(free.data.notes.single.hidden, isFalse);
    expect(free.lines[1].text, contains('PRO'));
    d = run(d, 'pin 선물');
    expect(d.pinned, d.notes.single.id);
    d = run(d, 'attrib +h 선물', pro: true);
    expect(d.notes.single.hidden, isTrue);
    expect(d.pinned, isNull);
    expect(d.listed(), isEmpty);
    expect(d.listed(showHidden: true), hasLength(1));
    expect(d.widgetNote, isNull);
    for (final c in ['type 선물', 'del 선물', 'ren 선물 비밀', 'pin 선물', 'echo x >> 선물']) {
      expect(go(d, c).lines.any((l) => l.kind == LogKind.err), isTrue, reason: c);
    }
    // 풀기는 화면이 Face ID 로 확인한 다음에
    final un = go(d, 'attrib -h 선물');
    expect(un.route, 'unhide');
    expect(un.data.notes.single.hidden, isTrue);
    // 여는 건 된다 (화면이 Face ID 를 먼저 물어본다)
    expect(go(d, 'edit 선물').route, 'edit');
  });

  test('dir /a 는 숨긴 파일까지', () {
    final d = NotepadData.empty();
    expect(go(d, 'dir /a').showHidden, isTrue);
    expect(go(d, 'dir').showHidden, isFalse);
    expect(go(d, 'ls -a').showHidden, isTrue);
  });

  test('명령어가 아닌 말은 빠른 메모에 시간과 함께, 모르는 영어 한 단어는 오류', () {
    var d = run(NotepadData.empty(), '택배 경비실에 맡김');
    d = run(d, '치과 금요일 7시');
    expect(d.byName(quickName)!.text, '오후 4:52  택배 경비실에 맡김\n오후 4:52  치과 금요일 7시');
    final typo = go(d, 'dri');
    expect(typo.lines[1].text, contains('내부 또는 외부 명령'));
    expect(typo.data.byName(quickName)!.text.contains('dri'), isFalse);
  });

  test('pin: 위젯 메모 고정 · 되돌리기', () {
    var d = run(NotepadData.empty(), 'edit 하나');
    d = run(d, 'edit 둘');
    d = run(d, 'pin 하나');
    expect(d.widgetNote!.name, '하나.txt');
    d = run(d, 'pin -');
    expect(d.pinned, isNull);
  });

  test('.LOG: 시간 찍기', () {
    expect(appendLogStamp('.LOG\n\n오전 9:00 2026-10-01\n비 옴\n\n', now), '.LOG\n\n오전 9:00 2026-10-01\n비 옴\n\n오후 4:52 2026-10-02\n');
    final n = Note(id: 1, name: 'a.txt', text: '.LOG\n', created: now, modified: now);
    expect(n.isLog, isTrue);
    expect(n.kind, '<LOG>');
  });

  test('저장했다 불러오기', () {
    var d = NotepadData.welcome(now);
    d = run(d, 'echo 우유 >> 장보기');
    d = run(d, 'attrib +h 장보기', pro: true);
    d = run(d, 'mode light');
    final back = NotepadData.fromJson(d.toJson());
    expect(back.notes.map((n) => n.name), [welcomeName, '장보기.txt']);
    expect(back.byName('장보기')!.hidden, isTrue);
    expect(back.mode, 'light');
    expect(back.nextId, d.nextId);
  });
}
