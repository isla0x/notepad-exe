import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
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

  static List<(String, String)> get _features => [
        (tr('pro.f1.t'), tr('pro.f1.d')),
        (tr('pro.f2.t'), tr('pro.f2.d')),
        (tr('pro.f3.t'), tr('pro.f3.d')),
        (tr('pro.f4.t'), tr('pro.f4.d')),
        (tr('pro.f5.t'), tr('pro.f5.d')),
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
                    Text(tr('pro.once'), style: termStyle(p.dim, size: 13)),
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
                            label: pro?.price == null ? tr('pro.buy') : tr('pro.buyp', {'p': pro!.price}),
                            onTap: () => pro?.buy(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TermBoxButton(
                                palette: p,
                                label: tr('pro.restore'),
                                textColor: p.cmd,
                                onTap: () => pro?.restore(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TermBoxButton(
                                palette: p,
                                label: tr('pro.esc'),
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        TermWideButton(
                          palette: p,
                          keyLabel: '[ ESC ]',
                          label: tr('btn.back'),
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
        Text(tr('pro.active'), style: termStyle(p.ok, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(tr('pro.a1'), style: termStyle(p.dim, size: 13)),
        const SizedBox(height: 4),
        Text(tr('pro.a2'), style: termStyle(p.dim, size: 13)),
        const SizedBox(height: 4),
        Text(tr('pro.a3'), style: termStyle(p.dim, size: 13)),
      ];

  List<Widget> _buyInfo(TermPalette p, ProController? pro) {
    final String status;
    if (pro == null || !pro.available) {
      status = tr('pro.nostore');
    } else if (pro.price == null) {
      status = tr('pro.loading');
    } else {
      status = tr('pro.price', {'p': pro.price});
    }
    return [
      Text(status, style: termStyle(p.fg, size: 13)),
      Text(tr('pro.appleid'), style: termStyle(p.dim, size: 13)),
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
    final lines = n == null ? <String>[tr('pro.nonote')] : n.text.split('\n').where((l) => l.trim().isNotEmpty).take(4).toList();
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
                  Text(tr('pro.enc.demo'), maxLines: 1, style: termStyle(p.acc, size: 11)),
                  Text('U2FsdGVkX19x4Q…', maxLines: 1, style: termStyle(p.dim, size: 11)),
                  const SizedBox(height: 8),
                  Text(tr('pro.txt.demo'), maxLines: 1, style: termStyle(p.fg, size: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
