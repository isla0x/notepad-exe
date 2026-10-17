import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../lock.dart';
import '../logic/notes.dart';
import '../state/notepad_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';
import 'home_screen.dart';

const _logo = '█   █  ███  █████ █████ ████   ███  ████ \n'
    '██  █ █   █   █   █     █   █ █   █ █   █\n'
    '█ █ █ █   █   █   ████  ████  █████ █   █\n'
    '█  ██ █   █   █   █     █     █   █ █   █\n'
    '█   █  ███    █   █████ █     █   █ ████ ';

/// 실행하면 처음 보이는 부팅 화면. 아무 데나 탭하면 건너뛴다.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key, required this.store, required this.unlocker});

  final NotepadStore store;
  final Unlocker unlocker;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  static const _steps = 6;
  Timer? _timer;
  int _step = 0;

  bool get _ready => _step >= _steps;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 220), (t) {
      if (!mounted || _ready) {
        t.cancel();
        return;
      }
      setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTap() {
    if (!_ready) {
      _timer?.cancel();
      setState(() => _step = _steps);
      return;
    }
    _enter();
  }

  void _enter() {
    Navigator.of(context).pushReplacement(termRoute(HomeScreen(store: widget.store, unlocker: widget.unlocker)));
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = store.palette;
    final now = store.now();
    final hidden = store.data.notes.where((n) => n.hidden).length;
    final date = '${now.year}-${two(now.month)}-${two(now.day)} (${weekdayShort(now.weekday)})';
    final lines = [
      (tr('b.cfg'), 'config'),
      (tr('b.files'), tr('b.n', {'n': store.data.notes.length - hidden})),
      (tr('b.date'), date),
      (tr('b.lock'), hidden == 0 ? tr('b.none') : tr('b.hid', {'n': hidden})),
      (tr('b.parser'), 'v1.0'),
    ];
    final cells = (_step * 20 / _steps).round();
    final pct = (_step * 100 / _steps).round();

    return Scaffold(
      backgroundColor: p.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TitleBar(palette: p, now: now),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: IntrinsicHeight(
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                label: 'NOTEPAD',
                                excludeSemantics: true,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(_logo, softWrap: false, style: termStyle(p.hi, size: 17, height: 1.05)),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text('NOTEPAD [Version 1.0.0]', style: termStyle(p.hi)),
                              Text(tr('tag'), style: termStyle(p.dim, size: 13)),
                              const SizedBox(height: 32),
                              Text.rich(TextSpan(children: [
                                TextSpan(text: 'C:\\> ', style: termStyle(p.dim)),
                                TextSpan(text: 'notepad.exe --boot', style: termStyle(p.cmd)),
                              ])),
                              const SizedBox(height: 10),
                              for (var i = 0; i < lines.length; i++)
                                if (i < _step)
                                  _BootLine(palette: p, status: '[ OK ]', label: lines[i].$1, value: lines[i].$2)
                                else if (i == _step)
                                  _BootLine(palette: p, status: '[ .. ]', label: lines[i].$1, value: '', pending: true),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '[${'█' * cells}${'░' * (20 - cells)}]',
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.clip,
                                      style: termStyle(p.acc, size: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('$pct%', style: termStyle(p.hi, size: 13)),
                                ],
                              ),
                              const Spacer(),
                              const SizedBox(height: 24),
                              Text(tr('b.tip', {'q': quickName}), style: termStyle(p.dim, size: 13)),
                              const SizedBox(height: 14),
                              AnimatedOpacity(
                                opacity: _ready ? 1 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: IgnorePointer(
                                  ignoring: !_ready,
                                  child: TermWideButton(
                                    palette: p,
                                    keyLabel: '[ ENTER ]',
                                    label: tr('b.start'),
                                    onTap: _enter,
                                    trailing: BlinkingCursor(style: termStyle(p.hi, size: 15)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootLine extends StatelessWidget {
  const _BootLine({
    required this.palette,
    required this.status,
    required this.label,
    required this.value,
    this.pending = false,
  });

  final TermPalette palette;
  final String status;
  final String label;
  final String value;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(status, style: termStyle(pending ? p.tag : p.ok, size: 13)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: termStyle(pending ? p.hi : p.fg, size: 13))),
          Text(value, style: termStyle(p.dim, size: 13)),
        ],
      ),
    );
  }
}
