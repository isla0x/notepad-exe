import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/commands.dart';
import '../logic/notes.dart';
import '../note_cipher.dart';
import '../pro/pro_controller.dart';
import '../theme/term_palette.dart';

/// 앱 상태. 명령어를 실행하고 폰 안에만 저장한다 (서버 없음).
class NotepadStore extends ChangeNotifier {
  NotepadStore({DateTime Function()? clock, this.pro, this.cipher}) : _clock = clock ?? DateTime.now {
    pro?.addListener(notifyListeners);
  }

  /// PRO 결제 상태 (잠금 · 위젯). 없으면 무료로 취급한다.
  final ProController? pro;
  bool get isPro => pro?.isPro ?? false;

  /// 잠긴 메모 암호화 (AES-256-GCM, 키는 키체인). 없으면 암호화를 못 쓴다.
  final NoteCipher? cipher;

  /// 암호화된 메모를 푼 내용: 편집하는 동안 메모리에만 있고 저장소에는 절대 쓰지 않는다.
  final Map<int, String> _plain = {};

  /// 편집을 시작할 때의 내용과 시각 (닫을 때 바뀌었으면 버전으로 남긴다)
  final Map<int, (String, DateTime)> _openedWith = {};

  final Map<int, Timer> _encTimers = {};
  final Map<int, int> _encSeq = {};

  static const _key = 'notepad_exe_state_v1';
  static const _maxLog = 8;
  static const _maxHistory = 50;

  final DateTime Function() _clock;
  NotepadData _data = NotepadData.empty();
  SharedPreferences? _prefs;
  Timer? _saveTimer;

  final List<LogLine> _log = [
    const LogLine(LogKind.info, "'help' 를 입력하면 명령어 목록을 볼 수 있어요."),
  ];
  final List<String> _history = [];

  /// dir /a 로 숨긴 파일까지 보는 중
  bool showHidden = false;

  /// del 의 (Y/N) 대답을 기다리는 메모
  int? pendingDelete;

  NotepadData get data => _data;
  List<LogLine> get log => List.unmodifiable(_log);
  List<String> get history => List.unmodifiable(_history);
  DateTime now() => _clock();
  List<Note> get listed => _data.listed(showHidden: showHidden);

  Brightness _brightness = Brightness.dark;
  set systemBrightness(Brightness value) {
    if (value == _brightness) return;
    _brightness = value;
    notifyListeners();
  }

  bool get lightMode => switch (_data.mode) {
        'light' => true,
        'dark' => false,
        _ => _brightness == Brightness.light,
      };

  TermPalette get palette => lightMode ? TermPalette.light : TermPalette.dark;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) {
      _data = NotepadData.welcome(_clock());
      _save();
      return;
    }
    try {
      _data = NotepadData.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (e) {
      debugPrint('notepad.exe: 저장된 데이터를 읽지 못했어요. ($e)');
    }
  }

  /// 명령어를 실행한다. 화면 이동은 돌려준 결과를 보고 화면이 한다.
  CommandResult? run(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (pendingDelete == null) {
      _history.add(s);
      if (_history.length > _maxHistory) _history.removeAt(0);
    }
    // 디버그 빌드 전용: 결제 없이 PRO 켜고 끄기.
    if (kDebugMode && pro != null && s.toLowerCase() == 'pro --dev') {
      pro!.debugToggle();
      return _apply(CommandResult(_data, [
        LogLine(LogKind.cmd, '$prompt $s'),
        LogLine(LogKind.info, '[dev] PRO ${pro!.isPro ? 'on' : 'off'}'),
      ]));
    }
    final pending = pendingDelete;
    pendingDelete = null;
    final out = runCommand(_data, s, _clock(), pro: isPro, pendingDelete: pending);
    if (out.showHidden != null) showHidden = out.showHidden!;
    if (out.askDelete != null) pendingDelete = out.askDelete;
    return _apply(out);
  }

  /// 지금 (Y/N) 을 묻고 있으면 그 질문.
  String? get question {
    final n = _data.byId(pendingDelete);
    return n == null ? null : 'C:\\notes\\${n.name}, 삭제하시겠습니까 (Y/N)?';
  }

  /// 화면에 보여줄 내용 (암호화된 메모는 풀어 둔 것)
  String textOf(Note n) => n.hidden ? (_plain[n.id] ?? (n.cipher == null ? n.text : '')) : n.text;

  /// 암호화된 메모를 푼다 (Face ID 를 통과한 뒤에 부른다). 실패하면 null.
  Future<String?> unlock(int id) async {
    final n = _data.byId(id);
    if (n == null) return null;
    if (!n.hidden) return n.text;
    if (_plain.containsKey(id)) return _plain[id];
    if (n.cipher == null) return _plain[id] = n.text; // 암호화 전 데이터
    final c = cipher;
    if (c == null) return null;
    try {
      return _plain[id] = await c.decrypt(n.cipher!);
    } catch (e) {
      debugPrint('notepad.exe: 해독 실패 ($e)');
      return null;
    }
  }

  /// 메모를 연다. .LOG 메모면 맨 끝에 지금 시간을 찍는다. 돌려주는 메모의 text 는 화면용(푼 내용).
  Note? open(int id) {
    final n = _data.byId(id);
    if (n == null) return null;
    final before = textOf(n);
    _openedWith[id] = (before, n.modified);
    var text = before;
    if (isLogText(text)) {
      text = appendLogStamp(text, _clock());
      // 화면을 만드는 중(initState)에 불리므로 알리지 않는다. 목록은 닫을 때 갱신된다.
      _setText(n, text, notify: false);
    }
    return (_data.byId(id) ?? n).copyWith(text: text);
  }

  /// 편집 중인 글 저장 (자주 불려도 저장소에는 잠깐 모았다가 쓴다).
  void updateText(int id, String text) {
    final n = _data.byId(id);
    if (n == null || textOf(n) == text) return;
    _setText(n, text);
  }

  void _setText(Note n, String text, {bool notify = true}) {
    if (n.hidden) {
      _plain[n.id] = text;
      _data = _data.replace(n.copyWith(modified: _clock()));
      _encTimers[n.id]?.cancel();
      _encTimers[n.id] = Timer(const Duration(milliseconds: 400), () => _encryptPlain(n.id));
    } else {
      _data = _data.replace(n.copyWith(text: text, modified: _clock()));
      _scheduleSave();
    }
    if (notify) notifyListeners();
  }

  /// 푼 내용을 다시 암호화해서 저장한다. 늦게 끝난 옛 작업은 버린다.
  Future<void> _encryptPlain(int id) async {
    _encTimers.remove(id)?.cancel();
    final plain = _plain[id];
    final c = cipher;
    if (plain == null || c == null) return;
    final seq = (_encSeq[id] ?? 0) + 1;
    _encSeq[id] = seq;
    final sealed = await c.encrypt(plain);
    final n = _data.byId(id);
    if (n == null || !n.hidden || _encSeq[id] != seq) return;
    _data = _data.replace(n.copyWith(text: '', cipher: () => sealed));
    _save();
  }

  /// 편집을 마치면: 버전을 남기고, 암호화된 메모는 다시 잠그고, 로그에 한 줄.
  Future<void> closed(int id) async {
    final n = _data.byId(id);
    final opened = _openedWith.remove(id);
    if (n == null) return;
    if (n.hidden) {
      await _encryptPlain(id);
      _plain.remove(id);
      _apply(CommandResult(_data, [LogLine(LogKind.ok, '✓ 암호화해서 저장했어요: ${n.name}')]));
      return;
    }
    var next = n;
    if (opened != null && opened.$1 != n.text) next = n.withVersion(opened.$1, opened.$2);
    _apply(CommandResult(_data.replace(next), [LogLine(LogKind.ok, '✓ 저장했어요: ${n.name} · ${comma(n.bytes)} 바이트')]));
  }

  /// cipher /e: 암호화해서 숨긴다 (PRO). 버전 기록은 지운다 (평문이 남지 않게).
  Future<void> encrypt(int id) async {
    final n = _data.byId(id);
    final c = cipher;
    if (n == null || n.hidden) return;
    if (c == null) {
      note('이 기기에서는 암호화를 쓸 수 없어요.', error: true);
      return;
    }
    try {
      final sealed = await c.encrypt(n.text);
      final cur = _data.byId(id) ?? n;
      _apply(CommandResult(
        _data
            .replace(cur.copyWith(hidden: true, text: '', cipher: () => sealed, versions: const []))
            .copyWith(pinned: () => _data.pinned == id ? null : _data.pinned),
        [
          LogLine(LogKind.ok, '✓ ${n.name} 을(를) 암호화했어요. (AES-256)'),
          const LogLine(LogKind.info, '목록에서 숨겨져요 · 보기: dir /a · 열 때 Face ID'),
        ],
      ));
    } catch (e) {
      note('암호화하지 못했어요. ($e)', error: true);
    }
  }

  /// cipher /d: Face ID 로 확인한 뒤 암호화를 푼다.
  Future<void> decrypt(int id) async {
    final text = await unlock(id);
    final n = _data.byId(id);
    if (n == null) return;
    if (text == null) {
      note('풀지 못했어요. 키를 찾을 수 없어요.', error: true);
      return;
    }
    _plain.remove(id);
    _apply(CommandResult(
      _data.replace(n.copyWith(hidden: false, text: text, cipher: () => null)),
      [LogLine(LogKind.ok, '✓ ${n.name} 암호화를 풀었어요.')],
    ));
  }

  /// fc 화면에서 그 버전으로 되돌리기. 지금 내용도 버전으로 남는다.
  void restoreVersion(int id, int index) {
    final n = _data.byId(id);
    if (n == null || n.hidden || index < 0 || index >= n.versions.length) return;
    final v = n.versions[index];
    final versions = [NoteVersion(n.modified, n.text), for (final x in n.versions) if (!identical(x, v)) x];
    _apply(CommandResult(
      _data.replace(n.copyWith(text: v.text, modified: _clock(), versions: versions.take(maxVersions).toList())),
      [LogLine(LogKind.ok, '✓ ${n.name} 을(를) ${dirTime(v.at)} 버전으로 되돌렸어요. 지금 것도 버전에 남아요.')],
    ));
  }

  /// 화면 로그에 안내 한 줄.
  void note(String text, {bool error = false}) =>
      _apply(CommandResult(_data, [LogLine(error ? LogKind.err : LogKind.info, text)]));

  void refresh() => notifyListeners();

  CommandResult _apply(CommandResult out) {
    final changed = !identical(out.data, _data);
    _data = out.data;
    if (out.clearLog) {
      _log.clear();
    } else {
      _log.addAll(out.lines);
      if (_log.length > _maxLog) _log.removeRange(0, _log.length - _maxLog);
    }
    notifyListeners();
    if (changed) _saveNow();
    return out;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  void _saveNow() {
    _saveTimer?.cancel();
    _save();
  }

  void _save() => _prefs?.setString(_key, jsonEncode(_data.toJson()));

  /// 앱이 뒤로 갈 때 아직 안 쓴 것을 쓴다.
  void flush() {
    if (_saveTimer?.isActive ?? false) _saveNow();
    for (final id in _encTimers.keys.toList()) {
      _encryptPlain(id);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final t in _encTimers.values) {
      t.cancel();
    }
    pro?.removeListener(notifyListeners);
    super.dispose();
  }
}
