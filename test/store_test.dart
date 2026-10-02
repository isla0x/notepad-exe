import 'package:flutter_test/flutter_test.dart';
import 'package:notepad_exe/logic/notes.dart';
import 'package:notepad_exe/note_cipher.dart';
import 'package:notepad_exe/state/notepad_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final now = DateTime(2026, 10, 2, 16, 52);
  const key = 'notepad_exe_state_v1';

  test('AES-256-GCM: 암호화하면 매번 다르고, 풀면 같다, 다른 키로는 못 푼다', () async {
    final c = MemoryCipher();
    final a = await c.encrypt('엄마 스카프');
    final b = await c.encrypt('엄마 스카프');
    expect(a, isNot(b));
    expect(await c.decrypt(a), '엄마 스카프');
    expect(() => MemoryCipher(List.filled(32, 1)).decrypt(a), throwsA(anything));
  });

  test('암호화된 메모: 저장소에는 평문이 남지 않는다', () async {
    final store = NotepadStore(clock: () => now, cipher: MemoryCipher());
    await store.load();
    store.run('echo 엄마 스카프 >> 선물');
    final id = store.data.byName('선물')!.id;
    store.run('pin 선물');
    await store.encrypt(id);
    final prefs = await SharedPreferences.getInstance();
    var n = store.data.byId(id)!;
    expect(n.hidden, isTrue);
    expect(n.text, '');
    expect(n.versions, isEmpty);
    expect(store.data.pinned, isNull);
    expect(prefs.getString(key)!.contains('스카프'), isFalse);

    // 열어서 고치고 닫기
    expect(await store.unlock(id), '엄마 스카프');
    expect(store.open(id)!.text, '엄마 스카프');
    store.updateText(id, '엄마 스카프\n아빠 지갑');
    expect(prefs.getString(key)!.contains('지갑'), isFalse);
    await store.closed(id);
    n = store.data.byId(id)!;
    expect(store.textOf(n), '');
    expect(prefs.getString(key)!.contains('지갑'), isFalse);
    expect(await store.unlock(id), '엄마 스카프\n아빠 지갑');

    // 풀기
    await store.decrypt(id);
    n = store.data.byId(id)!;
    expect(n.hidden, isFalse);
    expect(n.cipher, isNull);
    expect(n.text, '엄마 스카프\n아빠 지갑');
  });

  test('버전: 고치고 닫으면 고치기 전 내용이 남고, 되돌릴 수 있다', () async {
    final store = NotepadStore(clock: () => now);
    await store.load();
    store.run('echo 우유 >> 장보기');
    final id = store.data.byName('장보기')!.id;
    store.open(id);
    store.updateText(id, '우유\n두부');
    await store.closed(id);
    var n = store.data.byId(id)!;
    expect(n.versions.single.text, '우유');
    store.restoreVersion(id, 0);
    n = store.data.byId(id)!;
    expect(n.text, '우유');
    expect(n.versions.first.text, '우유\n두부');
    // 열고 안 고치고 닫으면 버전이 늘지 않는다
    store.open(id);
    await store.closed(id);
    expect(store.data.byId(id)!.versions, hasLength(1));
  });

  test('.LOG 는 열 때 시간이 찍히고, 암호화된 .LOG 도 된다', () async {
    final store = NotepadStore(clock: () => now, cipher: MemoryCipher());
    await store.load();
    store.run('echo .LOG > 출근');
    final id = store.data.byName('출근')!.id;
    await store.encrypt(id);
    await store.unlock(id);
    expect(store.open(id)!.text, '.LOG\n\n${logStamp(now)}\n');
    await store.closed(id);
    expect(await store.unlock(id), '.LOG\n\n${logStamp(now)}\n');
  });
}
