import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum UnlockResult { ok, cancelled, unavailable, error }

/// 잠긴 메모를 열 때 Face ID (안 되면 기기 암호) 로 확인한다.
abstract class Unlocker {
  Future<UnlockResult> unlock(String reason);
}

class DeviceUnlocker implements Unlocker {
  final _auth = LocalAuthentication();

  @override
  Future<UnlockResult> unlock(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) return UnlockResult.unavailable;
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      return ok ? UnlockResult.ok : UnlockResult.cancelled;
    } on PlatformException catch (e) {
      debugPrint('notepad.exe lock: ${e.code} ${e.message}');
      return switch (e.code) {
        'NotAvailable' || 'PasscodeNotSet' || 'NotEnrolled' => UnlockResult.unavailable,
        _ => UnlockResult.error,
      };
    }
  }
}

/// 테스트용: 늘 같은 답을 한다.
class FakeUnlocker implements Unlocker {
  FakeUnlocker([this.answer = UnlockResult.ok]);

  UnlockResult answer;
  int calls = 0;

  @override
  Future<UnlockResult> unlock(String reason) async {
    calls++;
    return answer;
  }
}

String unlockMessage(UnlockResult r) => switch (r) {
      UnlockResult.ok => '',
      UnlockResult.cancelled => '취소했어요. 잠긴 파일은 그대로예요.',
      UnlockResult.unavailable => '이 폰에 암호(Face ID)가 꺼져 있어서 열 수 없어요. 설정 > Face ID 및 암호에서 켜 주세요.',
      UnlockResult.error => '확인하지 못했어요. 잠시 후 다시 해 주세요.',
    };
