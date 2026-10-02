import 'package:flutter_test/flutter_test.dart';
import 'package:notepad_exe/logic/commands.dart';
import 'package:notepad_exe/logic/notes.dart';

void main() {
  final now = DateTime(2026, 10, 2, 16, 52);
  CommandResult go(NotepadData d, String s, {bool pro = false, int? pending}) =>
      runCommand(d, s, now, pro: pro, pendingDelete: pending);
  NotepadData run(NotepadData d, String s, {bool pro = false}) => go(d, s, pro: pro).data;
  // 암호화는 비동기라 store 가 한다: 여기서는 암호화된 모양만 만든다.
  NotepadData lock(NotepadData d, String name) {
    final n = d.byName(name)!;
    return d.replace(n.copyWith(hidden: true, text: '', cipher: () => 'U2FsdGVkX19x4Qm2vR8pKcT0n7wLh3Zs9bJdYq1eFtGuXo5MiAaPrSlVkNg2HcEyWzB6'));
  }

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
    d = lock(d, '비밀');
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

  test('cipher /e 는 PRO: 암호화는 store 가 (route encrypt)', () {
    final d = run(NotepadData.empty(), 'echo 엄마 스카프 >> 선물');
    final free = go(d, 'cipher /e 선물');
    expect(free.route, isNull);
    expect(free.lines[1].text, contains('PRO'));
    final pro = go(d, 'attrib +h 선물', pro: true);
    expect(pro.route, 'encrypt');
    expect(pro.noteId, d.notes.single.id);
    expect(pro.data.notes.single.hidden, isFalse);
  });

  test('암호화된 메모: 목록 · 위젯에서 빠지고, type 은 암호문, 나머지는 안 됨', () {
    var d = run(NotepadData.empty(), 'echo 엄마 스카프 >> 선물');
    d = lock(d, '선물');
    expect(d.listed(), isEmpty);
    expect(d.listed(showHidden: true).single.kind, '<ENC>');
    expect(d.widgetNote, isNull);
    final t = go(d, 'type 선물');
    expect(t.lines[1].kind, LogKind.enc);
    expect(t.lines[1].text, startsWith('U2FsdGVkX1'));
    expect(t.lines.any((l) => l.text.contains('스카프')), isFalse);
    for (final c in ['del 선물', 'ren 선물 비밀', 'pin 선물', 'echo x >> 선물', 'fc 선물', 'print 선물', 'cipher /e 선물']) {
      expect(go(d, c, pro: true).route, isNull, reason: c);
    }
    expect(go(d, 'cipher /d 선물').route, 'decrypt');
    expect(go(d, 'attrib -h 선물').route, 'decrypt');
    expect(go(d, 'edit 선물').route, 'edit');
    expect(go(d, 'cipher').lines.last.text, contains('선물.txt'));
  });

  test('fc: 버전이 있어야 열리고, echo > 는 이전 내용을 버전으로', () {
    var d = run(NotepadData.empty(), 'echo 우유 >> 장보기');
    expect(go(d, 'fc 장보기').route, isNull);
    d = run(d, 'echo 두부 > 장보기');
    final n = d.byName('장보기')!;
    expect(n.text, '두부');
    expect(n.versions.single.text, '우유');
    expect(go(d, 'fc 장보기').route, 'fc');
    expect(go(d, 'print 장보기').route, 'print');
    expect(go(d, 'print').lines[1].kind, LogKind.err);
  });

  test('diffLines: 지운 줄 · 더한 줄', () {
    final d = diffLines('우유 2개\n대파\n계란 한 판', '우유 2개\n계란 한 판\n두부');
    expect(d.map((x) => '${x.kind.name}:${x.text}'), ['same:우유 2개', 'removed:대파', 'same:계란 한 판', 'added:두부']);
  });

  test('withVersion: 최근 것부터, 같은 건 안 남기고, 최대 10개', () {
    final t = DateTime(2026, 10, 1);
    var n = Note(id: 1, name: 'a.txt', text: 'v0', created: t, modified: t);
    for (var i = 1; i <= 12; i++) {
      n = n.withVersion(n.text, t).copyWith(text: 'v$i');
    }
    expect(n.versions, hasLength(maxVersions));
    expect(n.versions.first.text, 'v11');
    expect(n.withVersion('v12', t).versions.first.text, 'v11');
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
    d = lock(d, '장보기');
    d = run(d, 'mode light');
    final back = NotepadData.fromJson(d.toJson());
    expect(back.notes.map((n) => n.name), [welcomeName, '장보기.txt']);
    expect(back.byName('장보기')!.hidden, isTrue);
    expect(back.mode, 'light');
    expect(back.nextId, d.nextId);
  });
}
