import 'package:flutter/material.dart';

import '../logic/commands.dart';
import '../pro/pro_controller.dart';
import '../state/notepad_store.dart';
import '../widgets/term_widgets.dart';
import '../theme/term_palette.dart';

/// (명령어, 인자, 설명, 예시)
const _entries = <(String, String, String, String?)>[
  ('edit', '<이름>', '메모 열기. 없으면 새로 만들어요. 쓰는 대로 저장돼요. (new · open 도 같아요)', 'edit 장보기'),
  ('dir', '[/a]', '메모 목록. 최근에 고친 것부터. /a 를 붙이면 숨긴 파일까지.', 'dir /a'),
  ('type', '<이름>', '내용을 화면에 보여줘요.', 'type 장보기'),
  ('echo', '<글> >> <이름>', '맨 끝에 한 줄 더하기. > 하나면 새로 쓰기. 없는 파일이면 만들어요.', 'echo 두부 >> 장보기'),
  ('find', '<말>', '모든 메모에서 찾기. 잠긴 파일은 찾지 않아요.', 'find 우유'),
  ('ren', '<이름> <새 이름>', '이름 바꾸기. 띄어쓰기가 있으면 "따옴표" 로.', 'ren "소설 아이디어" 소설'),
  ('del', '<이름>', '지우기. (Y/N) 으로 한 번 더 물어봐요.', 'del 장보기'),
  ('fc', '<이름> [/2]', '고치기 전 버전과 지금을 줄 단위로 비교 (- 지운 줄 · + 더한 줄). 그 버전으로 되돌리기도 돼요.', 'fc 장보기'),
  ('print', '<이름>', '메모를 옛날 컴퓨터 창 모양 이미지(1080 x 1350)로 저장 · 공유. retro · cmd · paper.', 'print 소설 아이디어'),
  ('pin', '<이름>', '위젯에 이 메모 고정. pin - 이면 최근에 고친 메모.', 'pin 장보기'),
  ('cls', '', '화면 로그만 지워요. 메모는 그대로예요.', null),
  ('mode', '[dark | light | auto]', '화면 밝기. auto 는 폰 설정을 따라가요.', 'mode light'),
  ('그냥 쓰기', '', '명령어가 아닌 말은 빠른 메모.txt 에 시간과 함께 저장돼요.', '택배 경비실에 맡김'),
  ('.LOG', '', '메모 첫 줄에 .LOG 라고 쓰면, 열 때마다 맨 끝에 지금 시간이 찍혀요.', null),
  ('F5', '', '편집 화면의 F5 시간 버튼: 커서 자리에 지금 시간.', null),
];

/// 아이폰에서만 보인다.
const _proEntries = <(String, String, String, String?)>[
  ('cipher /e', '<이름>', 'PRO · AES-256 으로 암호화하고 숨기기. 열 때 Face ID 로 확인하고 이 폰 안에서만 풀어요. (attrib +h 도 같아요)', 'cipher /e 비밀'),
  ('cipher /d', '<이름>', 'Face ID 로 확인하고 암호화 풀기. (attrib -h 도 같아요)', null),
  ('upgrade', '', 'PRO 소개와 구매. 암호화 + 홈 화면 · 잠금화면 위젯.', null),
  ('restore', '', '예전에 산 PRO 를 다시 불러와요. (기기 변경, 재설치)', null),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.store});

  final NotepadStore store;

  @override
  Widget build(BuildContext context) {
    final p = store.palette;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitleBar(palette: p, now: store.now(), tabs: const [TitleTab('help', active: true)]),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: '$prompt ', style: termStyle(p.fg)),
                  TextSpan(text: 'help', style: termStyle(p.cmd)),
                ])),
                const SizedBox(height: 10),
                Text('명령어 목록', style: termStyle(p.hi)),
                Text('메모 하나 = 파일 하나.  <필수>  [선택]  .txt 는 안 써도 돼요.', style: termStyle(p.dim, size: 13)),
                const SizedBox(height: 10),
                DashedDivider(color: p.line),
                for (final e in [..._entries, if (ProController.supported) ..._proEntries])
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(TextSpan(children: [
                          TextSpan(text: e.$1, style: termStyle(p.cmd)),
                          if (e.$2.isNotEmpty) TextSpan(text: ' ${e.$2}', style: termStyle(p.fg)),
                        ])),
                        const SizedBox(height: 2),
                        Text(e.$3, style: termStyle(p.dim, size: 13)),
                        if (e.$4 != null) Text('예) ${e.$4}', style: termStyle(p.tag, size: 13)),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Text('메모는 이 폰 안에만 저장돼요. 서버로 보내지 않아요.', style: termStyle(p.dim, size: 13)),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TermWideButton(
                palette: p,
                keyLabel: '[ ESC ]',
                label: '돌아가기',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
