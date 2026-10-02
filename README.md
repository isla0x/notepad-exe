# notepad.exe

메모도 파일처럼. 터미널 메모장. .exe 시리즈 (todo.exe · diary.exe · ink.exe · camera.exe · money.exe) 여섯 번째 앱.

```
C:\notes> dir
10-02 16:40  <TXT>  장보기.txt          52
10-01 09:03  <LOG>  출근 기록.txt       186
C:\notes> echo 두부 >> 장보기
✓ 장보기.txt 에 한 줄 더했어요.
```

- **메모 = 파일**: `edit 장보기` 로 열기(없으면 만들기), 쓰는 대로 저장. 목록을 누르면 열려요.
- **명령어**: `type` 보기 · `echo … >> 이름` 한 줄 더하기 · `find` 찾기 · `ren` 이름 바꾸기 · `del` 지우기 (Y/N)
- **그냥 쓰기**: 명령어가 아닌 말은 `빠른 메모.txt` 에 시간과 함께
- **.LOG**: 첫 줄이 `.LOG` 인 메모는 열 때마다 맨 끝에 `오후 4:52 2026-10-02` 가 찍혀요 (옛 메모장의 숨은 기능). 편집 화면의 `F5 시간` 은 커서 자리에.
- 메모는 폰 안에만 저장 (서버 없음, 데이터 수집 없음).

## 명령어

| 명령어 | 설명 |
| --- | --- |
| `edit 장보기` | 열기 · 없으면 새로 (new · open 도 같음) |
| `dir` · `dir /a` | 목록 (최근에 고친 순) · 숨긴 파일까지 |
| `type 장보기` | 내용 보기 |
| `echo 두부 >> 장보기` | 맨 끝에 한 줄 (`>` 하나면 새로 쓰기) |
| `find 우유` | 모든 메모에서 찾기 (잠긴 메모는 빼고) |
| `ren "소설 아이디어" 소설` | 이름 바꾸기 |
| `del 장보기` | 지우기, (Y/N) 확인 |
| `pin 장보기` · `pin -` | 위젯에 고정 · 최근 메모로 |
| `attrib +h 비밀` · `attrib -h 비밀` | 숨기고 Face ID 잠금 (PRO) · 풀기 |
| `mode dark` / `light` / `auto` | 화면 밝기 |
| `cls` · `help` | 로그 지우기 · 도움말 |

파일 이름에는 윈도우처럼 `\ / : * ? " < > |` 를 쓸 수 없어요. `.txt` 는 안 써도 붙어요.

## PRO (아이폰, 한 번 결제)

| 무료 | PRO |
|---|---|
| 메모 · 명령어 · .LOG · 찾기 전부 | 숨기기 + Face ID 잠금, 홈 화면 위젯(작게 · 중간), 잠금화면 위젯(직사각형 · 한 줄) |

- 상품 ID: `notepad_exe_pro` (비소모성 / Non-Consumable). 안드로이드에는 PRO 메뉴가 안 보여요.
- 잠긴 메모는 목록 · `find` · 위젯에서 빠지고, 열 때마다 Face ID(안 되면 기기 암호). 열어 둔 채 앱을 나가면 닫혀요.
- 잠금은 앱 안에서 가리는 것이고, 메모 자체는 iOS 기기 암호화로 보호돼요 (따로 암호화하지 않음).
- PRO 가 끝나도(복원 전) 이미 잠근 메모는 Face ID 로 열고 풀 수 있어요. 새로 잠그는 것만 PRO.
- 디버그 빌드에서만 `pro --dev` 로 결제 없이 PRO 를 켜고 끌 수 있어요.

## iOS 위젯

| 위치 | 크기 | 내용 |
|---|---|---|
| 홈 화면 | 작게 | 고정한 메모(pin, 없으면 최근 메모) 이름 + 다섯 줄. 누르면 그 메모 |
| 홈 화면 | 중간 | 위 + 최근 파일 3개(누르면 그 파일) + `C:\notes>` (누르면 입력칸) |
| 잠금화면 | 직사각형 | 메모 이름 + 두 줄 |
| 잠금화면 | 시계 위 한 줄 | 메모 첫 줄 |

`ios/` 에 위젯 타깃(NotepadWidget, App Group `group.com.isla0x.notepadexe`)까지 들어 있어요.
위젯 코드는 `ios_widget/` 에서 고치고 `bash tool/install_ios_widget.sh` 로 복사.

## 빌드 (Mac)

```bash
git pull
bash tool/setup_platforms.sh      # android/ 폴더 + 아이콘 (처음 한 번, 여러 번 돌려도 안전)
flutter build ipa                 # App Store
flutter build appbundle           # Google Play
```

- iOS 번들 ID: `com.isla0x.notepadExe` (위젯 `com.isla0x.notepadExe.NotepadWidget`) · Android 패키지: `com.isla0x.notepad_exe`
- Android 서명은 다른 앱과 같은 `~/.isla0x/android-upload.properties` 를 쓴다 (저장소에 절대 넣지 않음).
- GitHub Actions 가 push 마다 analyze · test · APK · iOS(서명 없이, 위젯 포함) 빌드를 확인한다.

아이콘 원본: `design/icons/e-mono-cursor.svg` (안드로이드 전경: `fg.svg`)
