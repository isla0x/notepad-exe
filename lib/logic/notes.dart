import 'dart:convert';

/// 밝기 모드. auto = 폰 설정을 따른다.
const modeIds = ['auto', 'light', 'dark'];

/// 고치기 전 내용 하나 (fc · ver)
class NoteVersion {
  const NoteVersion(this.at, this.text);

  /// 이 내용이 마지막으로 저장된 시각
  final DateTime at;
  final String text;

  Map<String, dynamic> toJson() => {'at': at.millisecondsSinceEpoch, 'text': text};

  factory NoteVersion.fromJson(Map<String, dynamic> j) =>
      NoteVersion(DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()), j['text'] as String? ?? '');
}

/// 메모마다 남기는 이전 버전 수
const maxVersions = 10;

/// 메모 하나 = 파일 하나.
class Note {
  const Note({
    required this.id,
    required this.name,
    required this.text,
    required this.created,
    required this.modified,
    this.hidden = false,
    this.cipher,
    this.versions = const [],
  });

  final int id;

  /// 장보기.txt
  final String name;

  /// 내용. 암호화된 메모는 비어 있고 [cipher] 에 들어 있다.
  final String text;
  final DateTime created;
  final DateTime modified;

  /// cipher /e (attrib +h): 숨기고 암호화. 열 때 Face ID 로 확인하고 이 폰 안에서만 푼다 (PRO).
  final bool hidden;

  /// AES-256-GCM 으로 암호화한 내용 (base64: nonce + 암호문 + MAC). 키는 키체인에만 있다.
  final String? cipher;

  /// 고치기 전 내용, 최근 것부터 (최대 [maxVersions]). 암호화된 메모는 남기지 않는다.
  final List<NoteVersion> versions;

  Note copyWith({
    String? name,
    String? text,
    DateTime? modified,
    bool? hidden,
    String? Function()? cipher,
    List<NoteVersion>? versions,
  }) =>
      Note(
        id: id,
        name: name ?? this.name,
        text: text ?? this.text,
        created: created,
        modified: modified ?? this.modified,
        hidden: hidden ?? this.hidden,
        cipher: cipher != null ? cipher() : this.cipher,
        versions: versions ?? this.versions,
      );

  /// [old] 를 버전으로 남긴다 (바로 앞 버전 · 지금과 같으면 그대로).
  Note withVersion(String old, DateTime at) {
    if (hidden || old == text || (versions.isNotEmpty && versions.first.text == old)) return this;
    return copyWith(versions: [NoteVersion(at, old), ...versions].take(maxVersions).toList());
  }

  bool get encrypted => hidden && cipher != null;

  /// 첫 줄이 .LOG 이면 열 때마다 시간이 찍힌다 (옛 메모장의 숨은 기능).
  bool get isLog => isLogText(text);

  /// UTF-8 바이트 수 (메모장이 보여주던 파일 크기). 암호화된 메모는 암호문 크기.
  int get bytes => utf8.encode(encrypted ? cipher! : text).length;

  int get lines => text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;

  /// `<TXT>` · `<LOG>` · `<ENC>`
  String get kind => hidden ? '<ENC>' : (isLog ? '<LOG>' : '<TXT>');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'text': text,
        'created': created.millisecondsSinceEpoch,
        'modified': modified.millisecondsSinceEpoch,
        if (hidden) 'hidden': true,
        if (cipher != null) 'cipher': cipher,
        if (versions.isNotEmpty) 'versions': [for (final v in versions) v.toJson()],
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        text: j['text'] as String? ?? '',
        created: DateTime.fromMillisecondsSinceEpoch((j['created'] as num?)?.toInt() ?? 0),
        modified: DateTime.fromMillisecondsSinceEpoch((j['modified'] as num?)?.toInt() ?? 0),
        hidden: j['hidden'] == true,
        cipher: j['cipher'] as String?,
        versions: [
          for (final v in (j['versions'] as List? ?? const [])) NoteVersion.fromJson(Map<String, dynamic>.from(v as Map)),
        ],
      );
}

/// 앱에 저장되는 전부. UI 와 저장소에 의존하지 않는다.
class NotepadData {
  const NotepadData({required this.notes, required this.nextId, this.mode = 'auto', this.pinned});

  factory NotepadData.empty() => const NotepadData(notes: [], nextId: 1);

  /// 처음 켰을 때: 사용법 메모 하나.
  factory NotepadData.welcome(DateTime now) => NotepadData(
        notes: [Note(id: 1, name: welcomeName, text: welcomeText, created: now, modified: now)],
        nextId: 2,
      );

  final List<Note> notes;
  final int nextId;

  /// 화면 밝기: auto | light | dark
  final String mode;

  /// 위젯에 보여줄 메모 (pin). 없으면 가장 최근에 고친 메모.
  final int? pinned;

  NotepadData copyWith({List<Note>? notes, int? nextId, String? mode, int? Function()? pinned}) => NotepadData(
        notes: notes ?? this.notes,
        nextId: nextId ?? this.nextId,
        mode: mode ?? this.mode,
        pinned: pinned != null ? pinned() : this.pinned,
      );

  Note? byId(int? id) {
    if (id == null) return null;
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// 이름으로 찾기 (대소문자 무시, .txt 생략 가능)
  Note? byName(String raw) {
    final name = normalizeName(raw);
    if (name == null) return null;
    final low = name.toLowerCase();
    for (final n in notes) {
      if (n.name.toLowerCase() == low) return n;
    }
    return null;
  }

  NotepadData replace(Note note) => copyWith(notes: [for (final n in notes) n.id == note.id ? note : n]);

  /// 새 메모를 만든다 (이름은 이미 검사했다고 본다).
  (NotepadData, Note) create(String name, DateTime now, {String text = ''}) {
    final note = Note(id: nextId, name: name, text: text, created: now, modified: now);
    return (copyWith(notes: [...notes, note], nextId: nextId + 1), note);
  }

  NotepadData remove(int id) =>
      copyWith(notes: [for (final n in notes) if (n.id != id) n], pinned: () => pinned == id ? null : pinned);

  /// 목록 순서: 최근에 고친 것부터.
  List<Note> listed({bool showHidden = false}) {
    final list = [for (final n in notes) if (showHidden || !n.hidden) n];
    list.sort((a, b) {
      final c = b.modified.compareTo(a.modified);
      return c != 0 ? c : b.id.compareTo(a.id);
    });
    return list;
  }

  /// 위젯에 보여줄 메모: pin 한 것, 없으면 가장 최근 것 (숨긴 메모는 절대 안 보여준다).
  Note? get widgetNote {
    final p = byId(pinned);
    if (p != null && !p.hidden) return p;
    final l = listed();
    return l.isEmpty ? null : l.first;
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'notes': [for (final n in notes) n.toJson()],
        'nextId': nextId,
        'mode': mode,
        if (pinned != null) 'pinned': pinned,
      };

  factory NotepadData.fromJson(Map<String, dynamic> j) {
    final notes = [
      for (final n in (j['notes'] as List? ?? const [])) Note.fromJson(Map<String, dynamic>.from(n as Map)),
    ];
    var next = (j['nextId'] as num?)?.toInt() ?? 1;
    for (final n in notes) {
      if (n.id >= next) next = n.id + 1;
    }
    return NotepadData(
      notes: notes,
      nextId: next,
      mode: modeIds.contains(j['mode']) ? j['mode'] as String : 'auto',
      pinned: (j['pinned'] as num?)?.toInt(),
    );
  }
}

const welcomeName = '처음 읽어 주세요.txt';
const welcomeText = 'notepad.exe 에 오신 걸 환영해요.\n'
    '메모 하나 = 파일 하나예요.\n'
    '\n'
    'edit 장보기          새 메모 (있으면 열기)\n'
    'dir                 메모 목록\n'
    'type 장보기          내용 보기\n'
    'find 우유            모든 메모에서 찾기\n'
    'echo 우유 >> 장보기   맨 끝에 한 줄 더하기\n'
    'ren 장보기 마트       이름 바꾸기\n'
    'del 장보기           지우기\n'
    'fc 장보기            고치기 전과 비교 · 되돌리기\n'
    'print 장보기         메모장 창 이미지로 저장 · 공유\n'
    '\n'
    '명령어가 아닌 말을 그냥 치면\n'
    '빠른 메모.txt 에 시간과 함께 저장돼요.\n'
    '\n'
    '첫 줄에 .LOG 라고 쓰면\n'
    '열 때마다 맨 끝에 지금 시간이 찍혀요.\n'
    '\n'
    '다 읽었으면: del 처음 읽어 주세요';

/// 첫 줄이 .LOG 인지
bool isLogText(String text) => text.split('\n').first.trim() == '.LOG';

// ---------------------------------------------------------------- 이름

/// 윈도우처럼 파일 이름에 쓸 수 없는 글자
const badNameChars = r'\ / : * ? " < > |';
final _badName = RegExp(r'[\\/:*?"<>|]');
final _ext = RegExp(r'\.[A-Za-z0-9]{1,4}$');
const maxNameLength = 40;

/// "장보기" → "장보기.txt". 쓸 수 없는 이름이면 null.
String? normalizeName(String raw) {
  var s = raw.trim();
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) s = s.substring(1, s.length - 1).trim();
  if (s.isEmpty || _badName.hasMatch(s) || s == '.' || s == '..') return null;
  if (!_ext.hasMatch(s)) s = '$s.txt';
  if (s.runes.length > maxNameLength) return null;
  return s;
}

/// "a b" "c d" 처럼 따옴표로 묶은 것은 한 덩어리로 자른다.
List<String> splitArgs(String s) {
  final out = <String>[];
  final re = RegExp(r'"([^"]*)"|(\S+)');
  for (final m in re.allMatches(s)) {
    out.add(m.group(1) ?? m.group(2)!);
  }
  return out;
}

// ---------------------------------------------------------------- 시간

String two(int n) => n.toString().padLeft(2, '0');

const weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

/// 10.02 금
String shortDate(DateTime d) => '${two(d.month)}.${two(d.day)} ${weekdayKo[d.weekday - 1]}';

/// 10-02 16:40 (dir 목록)
String dirTime(DateTime d) => '${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';

/// 오후 4:52
String clock12(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.hour < 12 ? '오전' : '오후'} $h:${two(d.minute)}';
}

/// 오후 4:52 2026-10-02 (옛 메모장의 F5 · .LOG 와 같은 모양)
String logStamp(DateTime d) => '${clock12(d)} ${d.year}-${two(d.month)}-${two(d.day)}';

/// 12,345
String comma(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// .LOG 메모를 열 때: 맨 끝에 빈 줄 + 지금 시간 + 줄바꿈.
String appendLogStamp(String text, DateTime now) {
  final base = text.replaceFirst(RegExp(r'\s+$'), '');
  return '$base\n\n${logStamp(now)}\n';
}

// ---------------------------------------------------------------- fc (줄 비교)

enum DiffKind { same, removed, added }

class DiffLine {
  const DiffLine(this.kind, this.text);

  final DiffKind kind;
  final String text;
}

/// 줄 단위 비교 (LCS). [older] → [newer] 로 바뀐 줄.
List<DiffLine> diffLines(String older, String newer) {
  final a = older.split('\n'), b = newer.split('\n');
  final n = a.length, m = b.length;
  final t = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      t[i][j] = a[i] == b[j] ? t[i + 1][j + 1] + 1 : (t[i + 1][j] >= t[i][j + 1] ? t[i + 1][j] : t[i][j + 1]);
    }
  }
  final out = <DiffLine>[];
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      out.add(DiffLine(DiffKind.same, a[i]));
      i++;
      j++;
    } else if (t[i + 1][j] >= t[i][j + 1]) {
      out.add(DiffLine(DiffKind.removed, a[i++]));
    } else {
      out.add(DiffLine(DiffKind.added, b[j++]));
    }
  }
  while (i < n) {
    out.add(DiffLine(DiffKind.removed, a[i++]));
  }
  while (j < m) {
    out.add(DiffLine(DiffKind.added, b[j++]));
  }
  return out;
}
