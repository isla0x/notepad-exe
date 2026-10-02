import 'package:flutter/material.dart';

import '../logic/commands.dart';
import '../logic/notes.dart';
import '../pro/pro_controller.dart';
import '../state/notepad_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';

/// `upgrade` 화면: PRO(잠금 + 아이폰 위젯) 소개 + 구매 / 복원.
class ProScreen extends StatelessWidget {
  const ProScreen({super.key, required this.store});

  final NotepadStore store;

  static const _features = [
    ('숨기기 · Face ID 잠금', 'attrib +h 비밀 → 목록에서 사라지고, 열 때마다 Face ID'),
    ('홈 화면 위젯', '작게 · 중간. 고정한 메모(pin) 또는 최근 메모, 파일 목록'),
    ('잠금화면 위젯', '직사각형 · 시계 위 한 줄'),
    ('위젯 누르면 그 메모가 바로', '중간 위젯은 파일마다 눌러서 열기'),
    ('앞으로 나올 PRO 기능', '추가 결제 없이'),
  ];

  @override
  Widget build(BuildContext context) {
    final pro = store.pro;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.palette;
        final isPro = store.isPro;
        return Scaffold(
          backgroundColor: p.bg,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TitleBar(palette: p, now: store.now()),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '$prompt ', style: termStyle(p.fg)),
                      TextSpan(text: 'upgrade', style: termStyle(p.cmd)),
                    ])),
                    const SizedBox(height: 14),
                    Text('notepad.exe PRO', style: termStyle(p.hi, size: 22, weight: FontWeight.w700)),
                    Text('한 번 결제, 계속 사용', style: termStyle(p.dim, size: 13)),
                    const SizedBox(height: 16),
                    _WidgetPreview(note: store.data.widgetNote, palette: p),
                    const SizedBox(height: 16),
                    DashedDivider(color: p.line),
                    const SizedBox(height: 8),
                    for (final f in _features)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isPro ? '[x]' : '[+]', style: termStyle(p.acc)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.$1, style: termStyle(p.hi)),
                                  Text(f.$2, style: termStyle(p.dim, size: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    DashedDivider(color: p.line),
                    const SizedBox(height: 14),
                    if (isPro) ..._activeInfo(p) else ..._buyInfo(p, pro),
                    if (pro?.message != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '> ${pro!.message}',
                          style: termStyle(pro.messageIsError ? p.warn : p.ok, size: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isPro) ...[
                        Opacity(
                          opacity: (pro?.busy ?? false) ? 0.5 : 1,
                          child: TermWideButton(
                            palette: p,
                            keyLabel: '[ ENTER ]',
                            label: pro?.price == null ? '구매하기' : '${pro!.price} 구매하기',
                            onTap: () => pro?.buy(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TermBoxButton(
                                palette: p,
                                label: '구매 복원',
                                textColor: p.cmd,
                                onTap: () => pro?.restore(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TermBoxButton(
                                palette: p,
                                label: '[ ESC ] 닫기',
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        TermWideButton(
                          palette: p,
                          keyLabel: '[ ESC ]',
                          label: '돌아가기',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _activeInfo(TermPalette p) => [
        Text('✓ PRO 활성화됨', style: termStyle(p.ok, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('잠그기: attrib +h 이름 · 풀기: attrib -h 이름', style: termStyle(p.dim, size: 13)),
        const SizedBox(height: 4),
        Text('홈 화면 위젯: 홈 화면 길게 누르기 → 편집 → 위젯 추가 → notepad.exe', style: termStyle(p.dim, size: 13)),
        const SizedBox(height: 4),
        Text('잠금화면 위젯: 잠금화면 길게 누르기 → 사용자화 → 잠금 화면 → 위젯', style: termStyle(p.dim, size: 13)),
      ];

  List<Widget> _buyInfo(TermPalette p, ProController? pro) {
    final String status;
    if (pro == null || !pro.available) {
      status = '스토어에 연결되지 않았어요.';
    } else if (pro.price == null) {
      status = '가격을 불러오는 중...';
    } else {
      status = '가격 ${pro.price} · 한 번만 결제';
    }
    return [
      Text(status, style: termStyle(p.fg, size: 13)),
      Text('같은 Apple ID 로는 다른 기기에서도 복원할 수 있어요.', style: termStyle(p.dim, size: 13)),
    ];
  }
}

/// 지금 내 메모로 그린 위젯 미리보기 (작게) + 잠긴 파일 한 줄.
class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({required this.note, required this.palette});

  final Note? note;
  final TermPalette palette;

  static const _bg = Color(0xFF0C0C0C);
  static const _hi = Color(0xFFF2F2F2);
  static const _fg = Color(0xFFCCCCCC);
  static const _dim = Color(0xFF8A8A8A);
  static const _acc = Color(0xFF6CA6FF);

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final n = note;
    final lines = n == null ? <String>['메모가 아직 없어요'] : n.text.split('\n').where((l) => l.trim().isNotEmpty).take(4).toList();
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 150,
            height: 150,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Text('>_ ', style: termStyle(_acc, size: 10, weight: FontWeight.w700)),
                  Text('notepad.exe', style: termStyle(_hi, size: 10, weight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Text(n?.name ?? 'C:\\notes', maxLines: 1, overflow: TextOverflow.ellipsis, style: termStyle(_acc, size: 10)),
                const SizedBox(height: 4),
                for (final l in lines)
                  Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: termStyle(_fg, size: 10, height: 1.4)),
                const Spacer(),
                Row(children: [
                  Text('C:\\notes>', style: termStyle(_dim, size: 10)),
                  Container(width: 6, height: 11, margin: const EdgeInsets.only(left: 3), color: _acc),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(border: Border.all(color: p.line)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('dir /a', style: termStyle(p.cmd, size: 11)),
                  const SizedBox(height: 6),
                  Text('<HID> 비밀.txt', maxLines: 1, style: termStyle(p.acc, size: 11)),
                  Text('잠김 · Face ID', style: termStyle(p.dim, size: 11)),
                  const SizedBox(height: 8),
                  Text('<TXT> 장보기.txt', maxLines: 1, style: termStyle(p.fg, size: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
