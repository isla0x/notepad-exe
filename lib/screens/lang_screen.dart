import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../logic/commands.dart' show prompt;
import '../state/notepad_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';

/// `lang` 화면: 언어 고르기. 처음엔 auto(폰 언어를 따라감).
class LangScreen extends StatelessWidget {
  const LangScreen({super.key, required this.store});

  final NotepadStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.palette;
        final pref = store.data.lang;
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
                      TextSpan(text: '$prompt ', style: termStyle(p.dim)),
                      TextSpan(text: 'lang', style: termStyle(p.cmd)),
                    ])),
                    const SizedBox(height: 14),
                    for (final code in L10n.prefs)
                      _LangRow(
                        palette: p,
                        code: code,
                        label: code == L10n.autoPref ? 'auto' : L10n.langFromCode(code)!.label,
                        note: code == L10n.autoPref ? L10n.device.label : null,
                        selected: pref == code,
                        onTap: () => store.run('lang $code'),
                      ),
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
                    label: tr('btn.back'),
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LangRow extends StatelessWidget {
  const _LangRow({
    required this.palette,
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
    this.note,
  });

  final TermPalette palette;
  final String code;
  final String label;
  final String? note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Semantics(
      button: true,
      selected: selected,
      label: note == null ? label : '$label, $note',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: Row(
            children: [
              Text(selected ? '[x]' : '[ ]', style: termStyle(selected ? p.ok : p.fg)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  note == null ? label : '$label  ($note)',
                  style: termStyle(selected ? p.hi : p.fg),
                ),
              ),
              Text(code, style: termStyle(p.dim, size: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
