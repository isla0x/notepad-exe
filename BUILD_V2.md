# notepad.exe 2.0.0

## 추가 기능: 연결 메모

메모 본문에 `[[장보기]]`를 적으면 편집창 아래 연결 버튼이 생깁니다. 없는 메모는 버튼을 눌러 만들고, 이미 있는 메모는 엽니다. 이 메모를 참조하는 메모도 표시합니다. 잠긴 메모를 열 때는 기존 인증 흐름을 거칩니다.

이 폴더에 기능을 추가한 소스가 들어 있습니다. GitHub main에는 아직 반영하지 않았습니다.

Mac 터미널에서:

```bash
cd "/Users/chaen/Documents/Codex/2026-10-23/new-chat-2/apps/notepad-exe-main"
bash tool/build_v2.sh
```

기본 빌드 번호는 2입니다. App Store Connect에 이미 사용한 번호라면 더 큰 숫자를 인자로 넣으세요.

```bash
bash tool/build_v2.sh 3
```

스크립트는 의존성을 받고 IPA를 빌드한 다음 Xcode 아카이브를 엽니다. Xcode의 Distribute App → App Store Connect에서 업로드합니다. 처음에는 Runner의 Signing & Capabilities에서 본인 개발팀이 선택되어 있어야 합니다.

검사:

```bash
flutter analyze --no-fatal-infos
flutter test
```

이 작업 환경에서는 정적 검사를 실행했습니다. Flutter 실행 테스트는 로컬 서버 소켓 생성 권한 제한으로 실행하지 못했습니다. 서명된 IPA 빌드 및 업로드는 실행하지 않았습니다.
