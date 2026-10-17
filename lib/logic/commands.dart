import '../l10n/l10n.dart';
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

const maxNotes = 500;
const maxTypeLines = 16;

/// 명령어 같은데 모르는 말 (오타): 메모로 저장하지 않고 알려준다.
final _commandLike = RegExp(r'^[a-z]{2,8}$');

/// (Y/N) 대답: 어느 언어로 답해도 된다.
final _yes = RegExp(r'^(y|yes|ㅛ|네|응|ㅇ|o|oui|はい|是|好|对|嗯)$', caseSensitive: false);

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
    final ask = LogLine(LogKind.cmd, tr('c.delq', {'name': note?.name ?? '', 's': s}));
    final yes = _yes.hasMatch(s);
    if (note == null || !yes) return CommandResult(d, [ask, LogLine(LogKind.info, tr('c.keep'))]);
    return CommandResult(d.remove(note.id), [ask, LogLine(LogKind.ok, tr('c.deleted', {'name': note.name}))]);
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
      if (m.isEmpty) return reply([LogLine(LogKind.info, tr('c.mode.hint'))]);
      if (!modeIds.contains(m)) return err(tr('c.mode.bad', {'a': arg}));
      return reply([LogLine(LogKind.ok, tr('c.mode.ok', {'m': _modeName(m)}))], data: d.copyWith(mode: m));

    case 'lang' || 'language':
      final v = arg.toLowerCase();
      if (v.isEmpty) {
        final how = d.lang == L10n.autoPref ? tr('l.how.auto') : tr('l.how.set');
        return CommandResult(
          d,
          [echo, LogLine(LogKind.info, tr('l.info', {'cur': L10n.current.label, 'how': how})), LogLine(LogKind.info, tr('l.hint'))],
          route: 'lang',
        );
      }
      if (!L10n.isPref(v)) return err(tr('l.bad', {'a': arg}));
      L10n.pref = v;
      final cur = v == L10n.autoPref ? L10n.device.label : L10n.langFromCode(v)!.label;
      return CommandResult(d.copyWith(lang: v), [echo, LogLine(LogKind.ok, tr('l.ok', {'cur': cur}))]);

    case 'edit' || 'new' || 'notepad' || 'open' || 'vi' || 'vim' || 'nano':
      if (arg.isEmpty) return err(tr('c.needname'), _eg('edit ${tr('x.groc')}'));
      final name = normalizeName(arg);
      if (name == null) return err(_badNameMessage(arg), tr('c.badchars', {'c': badNameChars}));
      final found = d.byName(name);
      if (found != null) return CommandResult(d, [echo], route: 'edit', noteId: found.id);
      if (d.notes.length >= maxNotes) return err(_fullMessage());
      final (data, note) = d.create(name, now);
      return CommandResult(data, [echo, LogLine(LogKind.ok, tr('c.newfile', {'name': note.name}))], route: 'edit', noteId: note.id);

    case 'type' || 'cat' || 'more':
      final note = _find(d, arg);
      if (note == null) return err(_notFound(arg));
      if (note.hidden) {
        final c = note.cipher ?? '';
        return reply([
          for (var i = 0; i < c.length && i < 44 * 3; i += 44) LogLine(LogKind.enc, c.substring(i, (i + 44).clamp(0, c.length))),
          if (c.length > 44 * 3) const LogLine(LogKind.enc, '...'),
          LogLine(LogKind.info, tr('c.encinfo', {'n': _bare(note.name)})),
        ]);
      }
      if (note.text.trim().isEmpty) return reply([LogLine(LogKind.info, tr('c.emptyfile'))]);
      final lines = note.text.split('\n');
      return reply([
        for (final l in lines.take(maxTypeLines)) LogLine(LogKind.text, l),
        if (lines.length > maxTypeLines)
          LogLine(LogKind.info, tr('c.more', {'n': lines.length - maxTypeLines, 'name': _bare(note.name)})),
      ]);

    case 'echo':
      final m = RegExp(r'^(.*?)\s*(>>?)\s*(.+)$').firstMatch(arg);
      if (m == null) return reply([LogLine(LogKind.text, arg)]);
      final text = m.group(1)!;
      final overwrite = m.group(2) == '>';
      final name = normalizeName(m.group(3)!);
      if (name == null) return err(_badNameMessage(m.group(3)!));
      final target = d.byName(name);
      if (target != null && target.hidden) return err(tr('c.echo.locked'));
      if (target == null) {
        if (d.notes.length >= maxNotes) return err(_fullMessage());
        final (data, note) = d.create(name, now, text: text);
        return reply([LogLine(LogKind.ok, tr('c.echo.new', {'name': note.name}))], data: data);
      }
      final next = overwrite ? text : _appendLine(target.text, text);
      final updated = target.copyWith(text: next, modified: now);
      return reply(
        [LogLine(LogKind.ok, tr(overwrite ? 'c.echo.over' : 'c.echo.add', {'name': target.name}))],
        data: d.replace(overwrite ? updated.withVersion(target.text, target.modified) : updated),
      );

    case 'find' || 'findstr' || 'grep' || 'search':
      final q = arg.length >= 2 && arg.startsWith('"') && arg.endsWith('"') ? arg.substring(1, arg.length - 1) : arg;
      if (q.isEmpty) return err(tr('c.find.need'), _eg('find ${tr('x.milk')}'));
      final low = q.toLowerCase();
      final out = <LogLine>[];
      var hits = 0;
      for (final n in d.listed()) {
        final lines = n.text.split('\n').where((l) => l.toLowerCase().contains(low)).toList();
        if (lines.isEmpty) continue;
        hits += lines.length;
        out.add(LogLine(LogKind.info, '---------- ${n.name}'));
        out.addAll(lines.take(5).map((l) => LogLine(LogKind.text, l.trim())));
        if (lines.length > 5) out.add(LogLine(LogKind.info, tr('c.find.more', {'n': lines.length - 5})));
      }
      if (hits == 0) return reply([LogLine(LogKind.info, tr('c.find.none', {'q': q}))]);
      return reply([...out, LogLine(LogKind.ok, tr('c.find.hits', {'n': hits}))]);

    case 'ren' || 'rename' || 'mv' || 'move':
      final a = splitArgs(arg);
      if (a.length != 2) return err(tr('c.ren.usage', {'a': tr('x.groc'), 'b': tr('x.mart')}), tr('c.ren.quote'));
      final note = _find(d, a[0]);
      if (note == null) return err(_notFound(a[0]));
      if (note.hidden) return err(tr('c.ren.locked'), tr('c.first.dec', {'n': _bare(note.name)}));
      final name = normalizeName(a[1]);
      if (name == null) return err(_badNameMessage(a[1]));
      final other = d.byName(name);
      if (other != null && other.id != note.id) return err(tr('c.ren.exists', {'name': other.name}));
      return reply([LogLine(LogKind.ok, '✓ ${note.name} → $name')], data: d.replace(note.copyWith(name: name)));

    case 'del' || 'rm' || 'erase' || 'delete':
      final note = _find(d, arg);
      if (note == null) return err(arg.isEmpty ? tr('c.del.need') : _notFound(arg));
      if (note.hidden) return err(tr('c.del.locked'), tr('c.first.dec', {'n': _bare(note.name)}));
      return CommandResult(d, [echo], askDelete: note.id);

    case 'attrib' || 'cipher':
      final a = splitArgs(arg);
      if (a.isEmpty) {
        final locked = [for (final n in d.notes) if (n.hidden) n];
        if (locked.isEmpty) return reply([LogLine(LogKind.info, tr('c.cipher.none'))]);
        return reply([for (final n in locked) LogLine(LogKind.enc, '  E    C:\\notes\\${n.name}')]);
      }
      final flag = a.first.toLowerCase();
      final lock = flag == '+h' || flag == '/e';
      final unlock = flag == '-h' || flag == '/d';
      final note = a.length >= 2 ? _find(d, a.sublist(1).join(' ')) : null;
      if ((!lock && !unlock) || a.length < 2) {
        return err(tr('c.cipher.usage', {'s': tr('x.secret')}), tr('c.cipher.usage2'));
      }
      if (note == null) return err(_notFound(a.sublist(1).join(' ')));
      if (lock) {
        if (note.hidden) return reply([LogLine(LogKind.info, tr('c.cipher.already', {'name': note.name}))]);
        if (!pro) return err(tr('c.cipher.pro'), tr('c.cipher.pro2'));
        return CommandResult(d, [echo], route: 'encrypt', noteId: note.id);
      }
      if (!note.hidden) return reply([LogLine(LogKind.info, tr('c.cipher.notenc', {'name': note.name}))]);
      return CommandResult(d, [echo], route: 'decrypt', noteId: note.id);

    case 'fc' || 'ver' || 'diff':
      final a = splitArgs(arg);
      if (a.isEmpty) return err(tr('c.needname'), _eg('fc ${tr('x.groc')}'));
      final note = _find(d, a.first);
      if (note == null) return err(_notFound(a.first));
      if (note.hidden) return err(tr('c.fc.locked'));
      if (note.versions.isEmpty) {
        return reply([LogLine(LogKind.info, tr('c.fc.none'))]);
      }
      return CommandResult(d, [echo], route: 'fc', noteId: note.id);

    case 'print' || 'export':
      final note = _find(d, arg);
      if (note == null) return err(arg.isEmpty ? tr('c.needname') : _notFound(arg), arg.isEmpty ? _eg('print ${tr('x.groc')}') : null);
      if (note.hidden) return err(tr('c.print.locked'));
      return CommandResult(d, [echo], route: 'print', noteId: note.id);

    case 'pin':
      if (arg.isEmpty) {
        final w = d.widgetNote;
        return reply([
          LogLine(
            LogKind.info,
            w == null ? tr('c.pin.none') : tr('c.pin.cur', {'name': w.name}) + (d.byId(d.pinned) == null ? tr('c.pin.recent') : ''),
          ),
          LogLine(LogKind.info, tr('c.pin.hint', {'g': tr('x.groc')})),
        ]);
      }
      if (arg == '-' || arg.toLowerCase() == 'off') {
        return reply([LogLine(LogKind.ok, tr('c.pin.reset'))], data: d.copyWith(pinned: () => null));
      }
      final note = _find(d, arg);
      if (note == null) return err(_notFound(arg));
      if (note.hidden) return err(tr('c.pin.locked'));
      return reply([LogLine(LogKind.ok, tr('c.pin.ok', {'name': note.name}))], data: d.copyWith(pinned: () => note.id));
  }

  // 명령어 같은데 모르는 말
  if (parts.length == 1 && _commandLike.hasMatch(head)) {
    return err(tr('c.unknown', {'c': parts.first}), tr('c.unknown2'));
  }

  // 그 밖에는 빠른 메모에 시간과 함께 (언어를 바꿨어도 예전 이름의 빠른 메모를 찾아 쓴다)
  final line = '${clock12(now)}  $s';
  Note? quick;
  for (final q in quickNames) {
    quick = d.byName(q);
    if (quick != null) break;
  }
  if (quick != null && quick.hidden) return err(tr('c.quick.locked', {'name': quick.name}));
  if (quick == null) {
    if (d.notes.length >= maxNotes) return err(_fullMessage());
    final (data, created) = d.create(quickName, now, text: line);
    return reply([LogLine(LogKind.ok, tr('c.quick.saved', {'name': created.name}))], data: data);
  }
  return reply(
    [LogLine(LogKind.ok, tr('c.quick.saved', {'name': quick.name}))],
    data: d.replace(quick.copyWith(text: _appendLine(quick.text, line), modified: now)),
  );
}

Note? _find(NotepadData d, String arg) => arg.trim().isEmpty ? null : d.byName(arg);

String _bare(String name) => name.endsWith('.txt') ? name.substring(0, name.length - 4) : name;

String _notFound(String arg) => tr('c.notfound', {'n': arg.trim()});

String _badNameMessage(String arg) => tr('c.badname', {'n': arg.trim()});

String _fullMessage() => tr('c.full', {'n': maxNotes});

String _eg(String cmd) => tr('ex', {'c': cmd});

String _appendLine(String text, String line) {
  final base = text.replaceFirst(RegExp(r'\s+$'), '');
  return base.isEmpty ? line : '$base\n$line';
}

String _modeName(String m) => switch (m) {
      'dark' => tr('c.mode.dark'),
      'light' => tr('c.mode.light'),
      _ => tr('c.mode.auto'),
    };
