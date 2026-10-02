import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'logic/notes.dart';

/// 홈 화면 · 잠금화면 위젯(iOS WidgetKit)으로 데이터를 넘기고, 위젯을 누르면 앱이 알게 한다.
///
/// 앱과 위젯은 App Group 저장소를 같이 쓴다. Runner 와 NotepadWidget 두 타깃 모두
/// [appGroupId] 로 App Groups 가 켜져 있다 (ios/ 에 들어 있음).
class WidgetSync {
  static const appGroupId = 'group.com.isla0x.notepadexe';
  static const iOSWidgetKind = 'NotepadWidget';
  static const snapshotKey = 'snapshot';

  /// 위젯을 누르면 열리는 주소. ios/Runner/Info.plist 의 URL scheme 과 같아야 한다.
  ///   notepadexe://open?id=3   그 메모 열기
  ///   notepadexe://new         입력칸 열기
  static const urlScheme = 'notepadexe';

  /// 위젯을 누를 때마다 바뀐다. 홈 화면이 듣고 메모를 열거나 입력칸을 연다.
  static final requests = ValueNotifier<WidgetRequest?>(null);

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// 위젯을 눌러서 앱이 켜졌으면 그 요청 (부팅 화면을 건너뛴다).
  static Future<WidgetRequest?> init() async {
    if (!_supported) return null;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      HomeWidget.widgetClicked.listen(
        (uri) {
          final r = WidgetRequest.parse(uri);
          if (r != null) requests.value = r;
        },
        onError: (Object e) => debugPrint('notepad.exe widget: $e'),
      );
      return WidgetRequest.parse(await HomeWidget.initiallyLaunchedFromHomeWidget());
    } catch (e) {
      debugPrint('notepad.exe widget: init 실패 ($e)');
      return null;
    }
  }

  static Future<void> push(NotepadData d, DateTime now, {required bool pro}) async {
    if (!_supported) return;
    try {
      await HomeWidget.saveWidgetData<String>(snapshotKey, jsonEncode(widgetSnapshot(d, now, pro: pro)));
      await HomeWidget.updateWidget(iOSName: iOSWidgetKind);
    } catch (e) {
      debugPrint('notepad.exe widget: 업데이트 실패 ($e)');
    }
  }
}

/// 위젯에서 온 요청: 메모 열기(id) 또는 새로 쓰기(id == null)
class WidgetRequest {
  WidgetRequest(this.noteId) : at = DateTime.now();

  final int? noteId;

  /// 같은 메모를 두 번 눌러도 알아차리도록
  final DateTime at;

  static WidgetRequest? parse(Uri? uri) {
    if (uri == null || uri.scheme != WidgetSync.urlScheme) return null;
    if (uri.host == 'open') {
      final id = int.tryParse(uri.queryParameters['id'] ?? '');
      if (id != null) return WidgetRequest(id);
    }
    return WidgetRequest(null);
  }
}

/// 위젯이 읽는 JSON. Swift 쪽 `NotepadSnapshot` 과 키가 같아야 한다.
/// 숨긴(잠긴) 메모는 이름도 내용도 절대 넣지 않는다.
Map<String, dynamic> widgetSnapshot(NotepadData d, DateTime now, {bool pro = false, int maxLines = 8, int maxRecent = 4}) {
  final w = d.widgetNote;
  final visible = d.listed();
  return {
    'v': 1,
    'pro': pro,
    'mode': d.mode,
    'count': visible.length,
    'note': w == null
        ? null
        : {
            'id': w.id,
            'name': w.name,
            'pinned': d.pinned == w.id,
            'when': dirTime(w.modified),
            'lines': w.text.split('\n').map((l) => l.trimRight()).where((l) => l.isNotEmpty).take(maxLines).toList(),
            'more': w.lines,
          },
    'recent': [
      for (final n in visible.take(maxRecent)) {'id': n.id, 'name': n.name, 'when': dirTime(n.modified), 'kind': n.kind},
    ],
  };
}
