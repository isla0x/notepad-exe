import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad_exe/lock.dart';
import 'package:notepad_exe/logic/notes.dart';
import 'package:notepad_exe/screens/home_screen.dart';
import 'package:notepad_exe/state/notepad_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(NotepadStore, FakeUnlocker)> pump(WidgetTester tester, {UnlockResult answer = UnlockResult.ok}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = NotepadStore(clock: () => DateTime(2026, 10, 2, 16, 52));
    await store.load();
    final unlocker = FakeUnlocker(answer);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(store: store, unlocker: unlocker)));
    return (store, unlocker);
  }

  Future<void> send(WidgetTester tester, String s) async {
    await tester.enterText(find.byType(TextField).last, s);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
  }

  testWidgets('처음엔 사용법 메모, edit 로 새 메모 쓰고 닫으면 목록에', (tester) async {
    final (store, _) = await pump(tester);
    expect(find.text(welcomeName), findsOneWidget);

    await send(tester, 'edit 장보기');
    expect(find.textContaining('edit 장보기.txt', findRichText: true), findsOneWidget);
    await tester.enterText(find.byType(TextField), '우유 2개\n두부');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('✓ 저장됨'), findsOneWidget);
    expect(find.text('줄 2 · 18 바이트'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('장보기.txt'), findsOneWidget);
    expect(store.data.byName('장보기')!.text, '우유 2개\n두부');
  });

  testWidgets('.LOG 메모는 열 때 시간이 찍힌다', (tester) async {
    final (store, _) = await pump(tester);
    store.run('echo .LOG > 출근');
    await tester.pump();
    await tester.tap(find.text('출근.txt'));
    await tester.pumpAndSettle();
    expect(store.data.byName('출근')!.text, '.LOG\n\n오후 4:52 2026-10-02\n');
    expect(find.textContaining('.LOG · 열 때마다'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
  });

  void saveLocked() {
    final t = DateTime(2026, 10, 1);
    final d = NotepadData(notes: [Note(id: 1, name: '선물.txt', text: '엄마 스카프', created: t, modified: t, hidden: true)], nextId: 2);
    SharedPreferences.setMockInitialValues({'notepad_exe_state_v1': jsonEncode(d.toJson())});
  }

  testWidgets('잠긴 메모: 목록에 안 보이고, dir /a 에서 눌러도 Face ID 를 취소하면 안 열린다', (tester) async {
    saveLocked();
    final (store, unlocker) = await pump(tester, answer: UnlockResult.cancelled);
    expect(find.text('선물.txt'), findsNothing);
    await send(tester, 'dir /a');
    expect(find.text('선물.txt'), findsOneWidget);
    expect(find.text('AES-256'), findsOneWidget);
    await tester.tap(find.text('선물.txt'));
    await tester.pumpAndSettle();
    expect(unlocker.calls, 1);
    expect(find.textContaining('edit 선물.txt', findRichText: true), findsNothing);
    expect(find.text('엄마 스카프'), findsNothing);
    expect(store.data.notes.single.hidden, isTrue);
  });

  testWidgets('잠긴 메모: Face ID 가 맞으면 열리고, attrib -h 로 풀린다', (tester) async {
    saveLocked();
    final (store, unlocker) = await pump(tester);
    await send(tester, 'edit 선물');
    expect(unlocker.calls, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('엄마 스카프'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    await send(tester, 'cipher /d 선물');
    expect(unlocker.calls, 2);
    expect(store.data.notes.single.hidden, isFalse);
    expect(find.text('선물.txt'), findsOneWidget);
  });

  testWidgets('del 은 Y/N 버튼으로', (tester) async {
    final (store, _) = await pump(tester);
    await send(tester, 'del 처음 읽어 주세요');
    expect(find.textContaining('삭제하시겠습니까 (Y/N)?'), findsOneWidget);
    await tester.tap(find.text('Y  지우기'));
    await tester.pumpAndSettle();
    expect(store.data.notes, isEmpty);
    expect(find.textContaining('파일이 없어요'), findsOneWidget);
  });
}
