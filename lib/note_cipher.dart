import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 잠긴 메모의 암호화 (cipher /e). AES-256-GCM, 키는 이 폰의 키체인에만 둔다.
abstract class NoteCipher {
  Future<String> encrypt(String plain);
  Future<String> decrypt(String cipher);
}

/// 실제 앱: 키를 처음 쓸 때 만들어 키체인에 넣는다.
///
/// 키체인 항목은 기기 백업(암호화된 백업)에는 같이 들어가서 새 폰으로 옮겨도 열린다.
/// 앱을 지우면 메모(앱 데이터)도 같이 지워진다.
class KeychainCipher implements NoteCipher {
  KeychainCipher({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _keyName = 'notepad_exe_cipher_key_v1';
  final FlutterSecureStorage _storage;
  SecretKey? _key;

  Future<SecretKey> _secret() async {
    if (_key != null) return _key!;
    var raw = await _storage.read(key: _keyName);
    if (raw == null) {
      final rnd = Random.secure();
      raw = base64Encode(List<int>.generate(32, (_) => rnd.nextInt(256)));
      await _storage.write(key: _keyName, value: raw);
    }
    return _key = SecretKey(base64Decode(raw));
  }

  @override
  Future<String> encrypt(String plain) async => sealText(await _secret(), plain);

  @override
  Future<String> decrypt(String cipher) async => openText(await _secret(), cipher);
}

/// 테스트 · 미리보기용: 메모리에만 있는 키.
class MemoryCipher implements NoteCipher {
  MemoryCipher([List<int>? key]) : _key = SecretKey(key ?? List<int>.generate(32, (i) => i * 7 % 256));

  final SecretKey _key;

  @override
  Future<String> encrypt(String plain) => sealText(_key, plain);

  @override
  Future<String> decrypt(String cipher) => openText(_key, cipher);
}

final _aes = AesGcm.with256bits();

/// base64(nonce 12 + 암호문 + MAC 16)
Future<String> sealText(SecretKey key, String plain) async {
  final box = await _aes.encrypt(utf8.encode(plain), secretKey: key);
  return base64Encode(box.concatenation());
}

Future<String> openText(SecretKey key, String cipher) async {
  final box = SecretBox.fromConcatenation(base64Decode(cipher), nonceLength: 12, macLength: 16);
  return utf8.decode(await _aes.decrypt(box, secretKey: key));
}
