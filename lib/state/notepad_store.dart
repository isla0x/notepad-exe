import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/commands.dart';
import '../logic/notes.dart';
import '../pro/pro_controller.dart';
import '../theme/term_palette.dart';

/// 앱 상태. 명령어를 실행하고 폰 안에만 저장한다 (서버 없음).
class NotepadStore extends ChangeNotifier {
  NotepadStore({DateTime Function()? clock, this.pro}) : _clock = clock ?? DateTime.now {
    pro?.addListener(notifyListeners);
  }

  /// PRO 결제 상태 (잠금 · 위젯). 없으면 무료로 취급한다.
  final ProController? pro;
  bool get isPro => pro?.isPro ?? false;

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

  /// 메모를 연다. .LOG 메모면 맨 끝에 지금 시간을 찍어서 돌려준다.
  Note? open(int id) {
    final n = _data.byId(id);
    if (n == null) return null;
    if (!n.isLog) return n;
    final stamped = n.copyWith(text: appendLogStamp(n.text, _clock()), modified: _clock());
    _data = _data.replace(stamped);
    _save();
    // 화면을 만드는 중(initState)에 불리므로 여기서는 알리지 않는다. 목록은 닫을 때 갱신된다.
    return stamped;
  }

  /// 편집 중인 글 저장 (자주 불려도 저장소에는 잠깐 모았다가 쓴다).
  void updateText(int id, String text) {
    final n = _data.byId(id);
    if (n == null || n.text == text) return;
    _data = _data.replace(n.copyWith(text: text, modified: _clock()));
    _scheduleSave();
    notifyListeners();
  }

  /// 편집을 마치면: 로그에 한 줄 남기고 바로 저장.
  void closed(int id) {
    final n = _data.byId(id);
    _saveNow();
    if (n == null) return;
    _apply(CommandResult(_data, [LogLine(LogKind.ok, '✓ 저장했어요: ${n.name} · ${comma(n.bytes)} 바이트')]));
  }

  /// Face ID 로 확인한 뒤 숨김 풀기.
  void unhide(int id) {
    final n = _data.byId(id);
    if (n == null) return;
    _apply(CommandResult(_data.replace(n.copyWith(hidden: false)), [LogLine(LogKind.ok, '✓ ${n.name} 잠금을 풀었어요.')]));
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
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    pro?.removeListener(notifyListeners);
    super.dispose();
  }
}
