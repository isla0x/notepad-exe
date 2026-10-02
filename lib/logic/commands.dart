import 'notes.dart';

/// 명령어 해석과 실행. UI 와 저장소에 의존하지 않는 순수 로직이라 테스트하기 쉽다.

enum LogKind { cmd, ok, err, info, text, enc }

class LogLine {
  const LogLine(this.kind, this.text);

  final LogKind kind;
  final String text;
}

class CommandResult {
  const CommandResult(
    this.data,
    this.lines, {
    this.route,
    this.noteId,
    this.clearLog = false,
    this.showHidden,
    this.askDelete,
  });

  final NotepadData data;
  final List<LogLine> lines;

  /// 열어야 할 화면: 'edit' | 'encrypt' | 'decrypt' | 'fc' | 'print' | 'help' | 'pro' | 'restore'
  ///   edit    = [noteId] 메모 열기 (암호화된 메모면 화면이 먼저 Face ID 로 확인하고 푼다)
  ///   encrypt = [noteId] 를 암호화해서 숨긴다 (PRO, 암호화는 비동기라 store 가 한다)
  ///   decrypt = Face ID 로 확인한 뒤 [noteId] 의 암호화를 푼다
  ///   fc      = [noteId] 의 이전 버전과 비교
  ///   print   = [noteId] 를 메모장 창 이미지로
  final String? route;
  final int? noteId;
  final bool clearLog;

  /// dir /a 이면 true, dir 이면 false, 그 밖엔 null(그대로)
  final bool? showHidden;

  /// del: 이 메모를 지울지 (Y/N) 물어본다. 다음 입력이 대답이다.
  final int? askDelete;
}

const prompt = 'C:\\notes>';

/// 그냥 쓴 말이 들어가는 메모
const quickName = '빠른 메모.txt';

const maxNotes = 500;
const maxTypeLines = 16;

/// 명령어 같은데 모르는 말 (오타): 메모로 저장하지 않고 알려준다.
final _commandLike = RegExp(r'^[a-z]{2,8}$');

CommandResult runCommand(
  NotepadData d,
  String raw,
  DateTime now, {
  bool pro = false,
  int? pendingDelete,
}) {
  final s = raw.trim();
  final echo = LogLine(LogKind.cmd, '$prompt $s');
  CommandResult reply(List<LogLine> lines, {NotepadData? data}) => CommandResult(data ?? d, [echo, ...lines]);
  CommandResult err(String m, [String? hint]) =>
      reply([LogLine(LogKind.err, m), if (hint != null) LogLine(LogKind.info, hint)]);

  // del 의 (Y/N) 대답
  if (pendingDelete != null) {
    final note = d.byId(pendingDelete);
    final ask = LogLine(LogKind.cmd, '${note?.name ?? ''}, 삭제하시겠습니까 (Y/N)? $s');
    final yes = RegExp(r'^(y|yes|ㅛ|네|응|ㅇ)$', caseSensitive: false).hasMatch(s);
    if (note == null || !yes) return CommandResult(d, [ask, const LogLine(LogKind.info, '지우지 않았어요.')]);
    return CommandResult(d.remove(note.id), [ask, LogLine(LogKind.ok, '✓ 지웠어요: ${note.name}')]);
  }

  final parts = s.split(RegExp(r'\s+'));
  final head = parts.first.toLowerCase();
  final arg = s.substring(parts.first.length).trim();

  switch (head) {
    case 'dir' || 'ls':
      return CommandResult(d, [echo], showHidden: RegExp(r'(^|\s)[/-]a', caseSensitive: false).hasMatch(arg));
    case 'cls' || 'clear':
      return CommandResult(d, const [], clearLog: true);
    case 'help' || '?':
      return CommandResult(d, [echo], route: 'help');
    case 'upgrade' || 'pro':
      return CommandResult(d, [echo], route: 'pro');
    case 'restore':
      return CommandResult(d, [echo], route: 'restore');
    case 'mode' || 'theme':
      final m = arg.toLowerCase();
      if (m.isEmpty) return reply(const [LogLine(LogKind.info, '바꾸려면: mode dark · mode light · mode auto')]);
      if (!modeIds.contains(m)) return err("모드를 알 수 없어요: '$arg' (dark · light · auto)");
      return reply([LogLine(LogKind.ok, '✓ 화면을 ${_modeName(m)}(으)로 바꿨어요.')], data: d.copyWith(mode: m));

    case 'edit' || 'new' || 'notepad' || 'open' || 'vi' || 'vim' || 'nano':
      if (arg.isEmpty) return err('파일 이름을 써 주세요.', '예) edit 장보기');
      final name = normalizeName(arg);
      if (name == null) return err(_badNameMessage(arg), '쓸 수 없는 글자: $badNameChars');
      final found = d.byName(name);
      if (found != null) return CommandResult(d, [echo], route: 'edit', noteId: found.id);
      if (d.notes.length >= maxNotes) return err('메모가 너무 많아요. (최대 $maxNotes개)');
      final (data, note) = d.create(name, now);
      return CommandResult(data, [echo, LogLine(LogKind.ok, '✓ 새 파일: ${note.name}')], route: 'edit', noteId: note.id);

    case 'type' || 'cat' || 'more':
      final note = _find(d, arg);
      if (note == null) return err(_notFound(arg));
      if (note.hidden) {
        final c = note.cipher ?? '';
        return reply([
          for (var i = 0; i < c.length && i < 44 * 3; i += 44) LogLine(LogKind.enc, c.substring(i, (i + 44).clamp(0, c.length))),
          if (c.length > 44 * 3) const LogLine(LogKind.enc, '...'),
          LogLine(LogKind.info, '암호화된 파일이에요. edit ${_bare(note.name)} 로 열면 Face ID 로 확인하고 풀어요.'),
        ]);
      }
      if (note.text.trim().isEmpty) return reply(const [LogLine(LogKind.info, '(빈 파일)')]);
      final lines = note.text.split('\n');
      return reply([
        for (final l in lines.take(maxTypeLines)) LogLine(LogKind.text, l),
        if (lines.length > maxTypeLines)
          LogLine(LogKind.info, '-- 더 보기 (${lines.length - maxTypeLines}줄) · edit ${_bare(note.name)} --'),
      ]);

    case 'echo':
      final m = RegExp(r'^(.*?)\s*(>>?)\s*(.+)$').firstMatch(arg);
      if (m == null) return reply([LogLine(LogKind.text, arg)]);
      final text = m.group(1)!;
      final overwrite = m.group(2) == '>';
      final name = normalizeName(m.group(3)!);
      if (name == null) return err(_badNameMessage(m.group(3)!));
      final target = d.byName(name);
      if (target != null && target.hidden) return err('암호화된 파일에는 쓸 수 없어요.');
      if (target == null) {
        if (d.notes.length >= maxNotes) return err('메모가 너무 많아요. (최대 $maxNotes개)');
        final (data, note) = d.create(name, now, text: text);
        return reply([LogLine(LogKind.ok, '✓ 새 파일 ${note.name} 에 썼어요.')], data: data);
      }
      final next = overwrite ? text : _appendLine(target.text, text);
      final updated = target.copyWith(text: next, modified: now);
      return reply(
        [LogLine(LogKind.ok, overwrite ? '✓ ${target.name} 을(를) 새로 썼어요. (이전 내용은 fc 로)' : '✓ ${target.name} 에 한 줄 더했어요.')],
        data: d.replace(overwrite ? updated.withVersion(target.text, target.modified) : updated),
      );

    case 'find' || 'findstr' || 'grep' || 'search':
      final q = arg.length >= 2 && arg.startsWith('"') && arg.endsWith('"') ? arg.substring(1, arg.length - 1) : arg;
      if (q.isEmpty) return err('찾을 말을 써 주세요.', '예) find 우유');
      final low = q.toLowerCase();
      final out = <LogLine>[];
      var hits = 0;
      for (final n in d.listed()) {
        final lines = n.text.split('\n').where((l) => l.toLowerCase().contains(low)).toList();
        if (lines.isEmpty) continue;
        hits += lines.length;
        out.add(LogLine(LogKind.info, '---------- ${n.name}'));
        out.addAll(lines.take(5).map((l) => LogLine(LogKind.text, l.trim())));
        if (lines.length > 5) out.add(LogLine(LogKind.info, '... ${lines.length - 5}줄 더'));
      }
      if (hits == 0) return reply([LogLine(LogKind.info, "'$q' 을(를) 찾지 못했어요. (암호화된 파일은 찾지 않아요)")]);
      return reply([...out, LogLine(LogKind.ok, '$hits줄 찾음')]);

    case 'ren' || 'rename' || 'mv' || 'move':
      final a = splitArgs(arg);
      if (a.length != 2) return err('사용법: ren 장보기 마트', '띄어쓰기가 있는 이름은 "따옴표" 로 묶어요.');
      final note = _find(d, a[0]);
      if (note == null) return err(_notFound(a[0]));
      if (note.hidden) return err('암호화된 파일은 이름을 바꿀 수 없어요.', '먼저 cipher /d ${_bare(note.name)}');
      final name = normalizeName(a[1]);
      if (name == null) return err(_badNameMessage(a[1]));
      final other = d.byName(name);
      if (other != null && other.id != note.id) return err('같은 이름의 파일이 이미 있습니다: ${other.name}');
      return reply([LogLine(LogKind.ok, '✓ ${note.name} → $name')], data: d.replace(note.copyWith(name: name)));

    case 'del' || 'rm' || 'erase' || 'delete':
      final note = _find(d, arg);
      if (note == null) return err(arg.isEmpty ? '지울 파일 이름을 써 주세요.' : _notFound(arg));
      if (note.hidden) return err('암호화된 파일은 지울 수 없어요.', '먼저 cipher /d ${_bare(note.name)}');
      return CommandResult(d, [echo], askDelete: note.id);

    case 'attrib' || 'cipher':
      final a = splitArgs(arg);
      if (a.isEmpty) {
        final locked = [for (final n in d.notes) if (n.hidden) n];
        if (locked.isEmpty) return reply(const [LogLine(LogKind.info, '암호화된 파일이 없어요. (잠그기: cipher /e 이름)')]);
        return reply([for (final n in locked) LogLine(LogKind.enc, '  E    C:\\notes\\${n.name}')]);
      }
      final flag = a.first.toLowerCase();
      final lock = flag == '+h' || flag == '/e';
      final unlock = flag == '-h' || flag == '/d';
      final note = a.length >= 2 ? _find(d, a.sublist(1).join(' ')) : null;
      if ((!lock && !unlock) || a.length < 2) {
        return err('사용법: cipher /e 비밀 (암호화해서 잠그기) · cipher /d 비밀 (풀기)', 'attrib +h · attrib -h 도 같아요.');
      }
      if (note == null) return err(_notFound(a.sublist(1).join(' ')));
      if (lock) {
        if (note.hidden) return reply([LogLine(LogKind.info, '${note.name} 은(는) 이미 암호화돼 있어요.')]);
        if (!pro) return err('암호화 잠금은 PRO 기능이에요.', "'upgrade' 로 자세히 볼 수 있어요.");
        return CommandResult(d, [echo], route: 'encrypt', noteId: note.id);
      }
      if (!note.hidden) return reply([LogLine(LogKind.info, '${note.name} 은(는) 암호화돼 있지 않아요.')]);
      return CommandResult(d, [echo], route: 'decrypt', noteId: note.id);

    case 'fc' || 'ver' || 'diff':
      final a = splitArgs(arg);
      if (a.isEmpty) return err('파일 이름을 써 주세요.', '예) fc 장보기');
      final note = _find(d, a.first);
      if (note == null) return err(_notFound(a.first));
      if (note.hidden) return err('암호화된 파일은 버전을 남기지 않아요.');
      if (note.versions.isEmpty) {
        return reply([const LogLine(LogKind.info, '아직 이전 버전이 없어요. 고치고 닫으면 고치기 전 내용이 남아요.')]);
      }
      return CommandResult(d, [echo], route: 'fc', noteId: note.id);

    case 'print' || 'export':
      final note = _find(d, arg);
      if (note == null) return err(arg.isEmpty ? '파일 이름을 써 주세요.' : _notFound(arg), arg.isEmpty ? '예) print 장보기' : null);
      if (note.hidden) return err('암호화된 파일은 이미지로 만들 수 없어요.');
      return CommandResult(d, [echo], route: 'print', noteId: note.id);

    case 'pin':
      if (arg.isEmpty) {
        final w = d.widgetNote;
        return reply([
          LogLine(LogKind.info, w == null ? '위젯에 보여줄 메모가 없어요.' : '위젯 메모: ${w.name}${d.byId(d.pinned) == null ? ' (최근에 고친 메모)' : ''}'),
          const LogLine(LogKind.info, '바꾸려면: pin 장보기 · 되돌리기: pin -'),
        ]);
      }
      if (arg == '-' || arg.toLowerCase() == 'off') {
        return reply([const LogLine(LogKind.ok, '✓ 위젯은 최근에 고친 메모를 보여줘요.')], data: d.copyWith(pinned: () => null));
      }
      final note = _find(d, arg);
      if (note == null) return err(_notFound(arg));
      if (note.hidden) return err('암호화된 파일은 위젯에 올릴 수 없어요.');
      return reply([LogLine(LogKind.ok, '✓ 위젯에 ${note.name} 을(를) 고정했어요.')], data: d.copyWith(pinned: () => note.id));
  }

  // 명령어 같은데 모르는 말
  if (parts.length == 1 && _commandLike.hasMatch(head)) {
    return err(
      "'${parts.first}'은(는) 내부 또는 외부 명령, 실행할 수 있는 프로그램, 또는 배치 파일이 아닙니다.",
      "'help' 를 입력하면 명령어를 볼 수 있어요.",
    );
  }

  // 그 밖에는 빠른 메모에 시간과 함께
  final line = '${clock12(now)}  $s';
  final quick = d.byName(quickName);
  if (quick != null && quick.hidden) return err('$quickName 이(가) 잠겨 있어서 쓸 수 없어요.');
  if (quick == null) {
    if (d.notes.length >= maxNotes) return err('메모가 너무 많아요. (최대 $maxNotes개)');
    final (data, _) = d.create(quickName, now, text: line);
    return reply(const [LogLine(LogKind.ok, '✓ $quickName 에 저장했어요.')], data: data);
  }
  return reply(
    const [LogLine(LogKind.ok, '✓ $quickName 에 저장했어요.')],
    data: d.replace(quick.copyWith(text: _appendLine(quick.text, line), modified: now)),
  );
}

Note? _find(NotepadData d, String arg) => arg.trim().isEmpty ? null : d.byName(arg);

String _bare(String name) => name.endsWith('.txt') ? name.substring(0, name.length - 4) : name;

String _notFound(String arg) => "파일을 찾을 수 없습니다: '${arg.trim()}'";

String _badNameMessage(String arg) => "쓸 수 없는 파일 이름이에요: '${arg.trim()}'";

String _appendLine(String text, String line) {
  final base = text.replaceFirst(RegExp(r'\s+$'), '');
  return base.isEmpty ? line : '$base\n$line';
}

String _modeName(String m) => switch (m) {
      'dark' => '다크',
      'light' => '라이트',
      _ => 'auto (폰 설정 따라감)',
    };
