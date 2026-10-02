import 'package:flutter/material.dart';

import '../logic/commands.dart';
import '../logic/notes.dart';
import '../state/notepad_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';

/// `fc 장보기`: 고치기 전 버전과 지금을 줄 단위로 비교하고, 그 버전으로 되돌린다.
class FcScreen extends StatefulWidget {
  const FcScreen({super.key, required this.store, required this.noteId});

  final NotepadStore store;
  final int noteId;

  @override
  State<FcScreen> createState() => _FcScreenState();
}

class _FcScreenState extends State<FcScreen> {
  int _pick = 0;

  NotepadStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.palette;
        final n = store.data.byId(widget.noteId);
        final versions = n?.versions ?? const <NoteVersion>[];
        if (n == null || versions.isEmpty) {
          return Scaffold(backgroundColor: p.bg, body: Column(children: [TitleBar(palette: p, now: store.now())]));
        }
        final pick = _pick.clamp(0, versions.length - 1);
        final v = versions[pick];
        final diff = diffLines(v.text, n.text);
        final plus = diff.where((d) => d.kind == DiffKind.added).length;
        final minus = diff.where((d) => d.kind == DiffKind.removed).length;
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
                      TextSpan(
                        text: 'fc ${_bare(n.name)}${pick == 0 ? '' : ' /${pick + 1}'}',
                        style: termStyle(p.cmd),
                      ),
                    ])),
                    const SizedBox(height: 4),
                    Text('비교 중: ${n.name} · ${dirTime(v.at)} ↔ 지금', style: termStyle(p.dim, size: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(color: p.line)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('***** ${dirTime(v.at)}', style: termStyle(p.dim, size: 12)),
                          for (final d in diff) _DiffRow(line: d, palette: p),
                          Text('***** 지금', style: termStyle(p.dim, size: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plus + minus == 0 ? '바뀐 줄이 없어요.' : '+$plus줄 · -$minus줄 바뀜',
                      style: termStyle(p.dim, size: 13),
                    ),
                    const SizedBox(height: 18),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '$prompt ', style: termStyle(p.fg)),
                      TextSpan(text: 'ver ${_bare(n.name)}', style: termStyle(p.cmd)),
                    ])),
                    Text('고치고 닫을 때마다 남아요 (최대 $maxVersions개) · 눌러서 비교', style: termStyle(p.dim, size: 12)),
                    const SizedBox(height: 8),
                    _VersionRow(palette: p, mark: '●', label: '지금', preview: n.text, selected: false),
                    for (var i = 0; i < versions.length; i++)
                      _VersionRow(
                        palette: p,
                        mark: i == pick ? '▶' : '',
                        label: dirTime(versions[i].at),
                        preview: versions[i].text,
                        selected: i == pick,
                        onTap: () => setState(() => _pick = i),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: TermBoxButton(
                            palette: p,
                            label: '이 버전으로',
                            textColor: p.acc,
                            semanticLabel: '${dirTime(v.at)} 버전으로 되돌리기',
                            onTap: () {
                              store.restoreVersion(n.id, pick);
                              Navigator.of(context).maybePop();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TermWideButton(
                          palette: p,
                          keyLabel: '[ ESC ]',
                          label: '닫기',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
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

  static String _bare(String name) => name.endsWith('.txt') ? name.substring(0, name.length - 4) : name;
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({required this.line, required this.palette});

  final DiffLine line;
  final TermPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final (sign, color, bg) = switch (line.kind) {
      DiffKind.removed => ('-', p.warn, p.warn.withAlpha(30)),
      DiffKind.added => ('+', p.ok, p.ok.withAlpha(28)),
      DiffKind.same => (' ', p.fg, Colors.transparent),
    };
    return Semantics(
      label: '${switch (line.kind) { DiffKind.removed => '지운 줄', DiffKind.added => '더한 줄', DiffKind.same => '같은 줄' }}: ${line.text}',
      excludeSemantics: true,
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 16, child: Text(sign, style: termStyle(color, size: 14))),
            Expanded(child: Text(line.text.isEmpty ? ' ' : line.text, style: termStyle(color, size: 14))),
          ],
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.palette,
    required this.mark,
    required this.label,
    required this.preview,
    required this.selected,
    this.onTap,
  });

  final TermPalette palette;
  final String mark;
  final String label;
  final String preview;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        button: onTap != null,
        selected: selected,
        label: '$label 버전',
        child: Material(
          color: selected ? p.acc.withAlpha(26) : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(border: Border.all(color: selected ? p.acc : p.line)),
              child: Row(
                children: [
                  SizedBox(width: 20, child: Text(mark, style: termStyle(p.acc, size: 13))),
                  SizedBox(width: 100, child: Text(label, style: termStyle(p.hi, size: 13))),
                  Expanded(
                    child: Text(
                      preview.split('\n').where((l) => l.trim().isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: termStyle(p.dim, size: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
