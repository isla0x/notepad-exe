#!/usr/bin/env bash
# 위젯 코드(ios_widget/)를 고친 뒤 실행: ios/NotepadWidget/ 에 덮어쓴다. (타깃은 ios/ 에 이미 들어 있다)
set -euo pipefail
cd "$(dirname "$0")/.."

DEST=ios/NotepadWidget
if [ ! -d "$DEST" ]; then
  echo "ios/NotepadWidget 폴더가 없어요."
  echo "Xcode 에서 File > New > Target > Widget Extension 으로 이름을 'NotepadWidget' 으로 먼저 만들어 주세요."
  exit 1
fi

cp ios_widget/NotepadWidget.swift "$DEST/NotepadWidget.swift"
cp ios_widget/NotepadWidgetBundle.swift "$DEST/NotepadWidgetBundle.swift"
cp ios_widget/PrivacyInfo.xcprivacy "$DEST/PrivacyInfo.xcprivacy"
# Xcode 가 만든 예시 파일은 지운다 (같은 이름의 위젯이 두 번 생기지 않게)
rm -f "$DEST/NotepadWidgetLiveActivity.swift" "$DEST/NotepadWidgetControl.swift" "$DEST/AppIntent.swift"
echo "위젯 코드를 $DEST 에 복사했어요."
