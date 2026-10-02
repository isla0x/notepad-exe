#!/usr/bin/env bash
# android/ ios/ 폴더가 없으면 만들고, 앱 이름과 Face ID · 사진 저장 권한 문구를 넣는다.
# 여러 번 돌려도 안전하다. (이미 있는 설정은 건드리지 않는다)
set -euo pipefail
cd "$(dirname "$0")/.."

# 터미널이 flutter 를 못 찾으면: zsh 설정(~/.zshrc 의 PATH · alias)과 흔한 설치 위치에서 찾아 본다.
if ! command -v flutter >/dev/null 2>&1; then
  found=""
  if command -v zsh >/dev/null 2>&1; then
    found=$(zsh -ic 'print -r -- ${commands[flutter]:-${aliases[flutter]}}' 2>/dev/null | tail -1 | sed "s/^[\"']//; s/[\"']$//; s/^~/${HOME//\//\\/}/")
  fi
  for c in "$found" "$HOME/development/flutter/bin/flutter" "$HOME/flutter/bin/flutter" "$HOME/Developer/flutter/bin/flutter" \
           "$HOME/fvm/default/bin/flutter" /opt/homebrew/bin/flutter /usr/local/bin/flutter; do
    if [ -n "$c" ] && [ -x "$c" ]; then
      export PATH="$(dirname "$c"):$PATH"
      echo "flutter 찾음: $c"
      break
    fi
  done
  if ! command -v flutter >/dev/null 2>&1; then
    echo "flutter 를 찾지 못했어요. 평소에 flutter build ipa 를 하던 터미널에서 'which flutter' 를 쳐서 나온 경로를 알려 주세요."
    exit 1
  fi
fi

if [ ! -d android ] || [ ! -d ios ]; then
  flutter create --org com.isla0x --project-name notepad_exe --platforms android,ios .
  # flutter create 가 만든 기본 테스트는 이 앱과 맞지 않아서 지운다.
  rm -f test/widget_test.dart
fi

python3 - <<'PY'
import re, pathlib

# --- iOS: 표시 이름 + 권한 문구 (ios/ 는 위젯 타깃까지 저장소에 들어 있다) ---
plist = pathlib.Path("ios/Runner/Info.plist")
if plist.exists():
    s = plist.read_text()
    s = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", r"\1notepad.exe\2", s)
    keys = {
        "NSFaceIDUsageDescription": "Uses Face ID to open the notes you have encrypted.",
        "NSPhotoLibraryAddUsageDescription": "Saves the image of your note to your photo library.",
    }
    add = "".join(
        f"\t<key>{k}</key>\n\t<string>{v}</string>\n" for k, v in keys.items() if f"<key>{k}</key>" not in s
    )
    # 위젯을 누르면 notepadexe://open?id=3 · notepadexe://new 로 앱이 열린다
    if "<key>CFBundleURLTypes</key>" not in s:
        add += ("\t<key>CFBundleURLTypes</key>\n\t<array>\n\t\t<dict>\n"
                "\t\t\t<key>CFBundleURLName</key>\n\t\t\t<string>com.isla0x.notepadExe</string>\n"
                "\t\t\t<key>CFBundleURLSchemes</key>\n\t\t\t<array>\n\t\t\t\t<string>notepadexe</string>\n\t\t\t</array>\n"
                "\t\t</dict>\n\t</array>\n")
    # 암호화 안 씀 (App Store 수출 규정 질문을 건너뛴다)
    if "<key>ITSAppUsesNonExemptEncryption</key>" not in s:
        add += "\t<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>\n"
    if add:
        i = s.rfind("</dict>")
        s = s[:i] + add + s[i:]
    plist.write_text(s)

# --- Android: 표시 이름 ---
manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
if manifest.exists():
    s = manifest.read_text()
    s = re.sub(r'android:label="[^"]*"', 'android:label="notepad.exe"', s, count=1)
    # 옛 기기(Android 10 이하)에서 사진 저장
    if "xmlns:tools=" not in s:
        s = s.replace("<manifest ", '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)
    perm = ('<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" '
            'android:maxSdkVersion="29" tools:replace="android:maxSdkVersion" />')
    if "WRITE_EXTERNAL_STORAGE" not in s:
        s = s.replace("<application", perm + "\n    <application", 1)
    manifest.write_text(s)

# --- Android: local_auth(Face ID · 지문)는 FlutterFragmentActivity 가 필요하다 ---
for main in pathlib.Path("android/app/src/main").rglob("MainActivity.kt"):
    s = main.read_text()
    if "FlutterFragmentActivity" not in s:
        s = s.replace("io.flutter.embedding.android.FlutterActivity", "io.flutter.embedding.android.FlutterFragmentActivity")
        s = s.replace(": FlutterActivity()", ": FlutterFragmentActivity()")
        main.write_text(s)

# --- Android: Google Play 서명(~/.isla0x 업로드 키) · API 36 이 들어간 앱 빌드 설정 ---
app_gradle = pathlib.Path("android/app/build.gradle.kts")
if app_gradle.exists() and "android-upload.properties" not in app_gradle.read_text():
    app_gradle.write_text(pathlib.Path("tool/templates/app.build.gradle.kts").read_text())

# --- Android: compileSdk 가 낮은 플러그인도 최신 SDK 로 빌드한다 ---
root = pathlib.Path("android/build.gradle.kts")
if root.exists():
    s = root.read_text()
    mark = "// notepad.exe: plugin compileSdk"
    if mark not in s:
        block = mark + """
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null && plugins.hasPlugin("com.android.library")) {
            try {
                android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                    .invoke(android, java.lang.Integer.valueOf(36))
            } catch (e: NoSuchMethodException) {
                android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType).invoke(android, 36)
            }
        }
    }
}

"""
        anchor = "subprojects {\n    project.evaluationDependsOn"
        i = s.find(anchor)
        s = s[:i] + block + s[i:] if i >= 0 else s + "\n" + block
        root.write_text(s)
PY

# 패키지 받고 앱 아이콘(assets/icon) 을 iOS · Android 에 넣는다.
flutter pub get
dart run flutter_launcher_icons

echo "platform folders ready."
