import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../logic/commands.dart';
import '../logic/notes.dart' show quickName;
import '../pro/pro_controller.dart';
import '../state/notepad_store.dart';
import '../widgets/term_widgets.dart';
import '../theme/term_palette.dart';

/// (명령어, 인자, 설명 키, 예시) — 글은 모두 tr() 로 지금 언어에 맞춘다.
List<(String, String, String, String?)> _entries() {
  final g = tr('x.groc');
  return [
    ('edit', tr('arg.name'), 'help.edit', 'edit $g'),
    ('dir', '[/a]', 'help.dir', 'dir /a'),
    ('type', tr('arg.name'), 'help.type', 'type $g'),
    ('echo', '${tr('arg.text')} >> ${tr('arg.name')}', 'help.echo', 'echo ${tr('x.tofu')} >> $g'),
    ('find', tr('arg.word'), 'help.find', 'find ${tr('x.milk')}'),
    ('ren', '${tr('arg.name')} ${tr('arg.newname')}', 'help.ren', 'ren "${tr('x.novel')}" ${tr('x.novel2')}'),
    ('del', tr('arg.name'), 'help.del', 'del $g'),
    ('fc', '${tr('arg.name')} [/2]', 'help.fc', 'fc $g'),
    ('print', tr('arg.name'), 'help.print', 'print ${tr('x.novel')}'),
    ('pin', tr('arg.name'), 'help.pin', 'pin $g'),
    ('cls', '', 'help.cls', null),
    ('mode', '[dark | light | auto]', 'help.mode', 'mode light'),
    ('lang', '[auto | ko | en | ja | zh | fr]', 'help.lang', 'lang en'),
    (tr('help.quick'), '', 'help.quickd', tr('x.parcel')),
    ('.LOG', '', 'help.log', null),
    ('F5', '', 'help.f5', null),
  ];
}

/// 아이폰에서만 보인다.
List<(String, String, String, String?)> _proEntries() => [
      ('cipher /e', tr('arg.name'), 'help.cenc', 'cipher /e ${tr('x.secret')}'),
      ('cipher /d', tr('arg.name'), 'help.cdec', null),
      ('upgrade', '', 'help.upgrade', null),
      ('restore', '', 'help.restore', null),
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
                Text(tr('help.title'), style: termStyle(p.hi)),
                Text(tr('help.sub'), style: termStyle(p.dim, size: 13)),
                const SizedBox(height: 10),
                DashedDivider(color: p.line),
                for (final e in [..._entries(), if (ProController.supported) ..._proEntries()])
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
                        Text(tr(e.$3, {'q': quickName}), style: termStyle(p.dim, size: 13)),
                        if (e.$4 != null) Text(tr('ex', {'c': e.$4}), style: termStyle(p.tag, size: 13)),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Text(tr('help.foot'), style: termStyle(p.dim, size: 13)),
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
  }
}
