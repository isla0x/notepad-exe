import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lock.dart';
import '../logic/commands.dart';
import '../logic/notes.dart';
import '../pro/pro_controller.dart';
import '../state/notepad_store.dart';
import '../theme/term_palette.dart';
import '../widget_sync.dart';
import '../widgets/term_widgets.dart';
import '../l10n/l10n.dart';
import 'editor_screen.dart';
import 'fc_screen.dart';
import 'help_screen.dart';
import 'lang_screen.dart';
import 'print_screen.dart';
import 'pro_screen.dart';

/// 메인 화면: dir 목록 + 명령어 입력창.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store, required this.unlocker, this.initial});

  final NotepadStore store;
  final Unlocker unlocker;

  /// 위젯을 눌러서 왔으면 그 메모(또는 입력칸)를 바로 연다.
  final WidgetRequest? initial;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _logScroll = ScrollController();
  int? _histIdx;
  bool _busy = false;

  NotepadStore get store => widget.store;

  /// (칩 이름, 누르면 채워 넣을 글자 — null 이면 바로 실행)
  static const _chips = <(String, String?)>[
    ('edit', 'edit '),
    ('dir', null),
    ('find', 'find '),
    ('type', 'type '),
    ('echo >>', 'echo  >> '),
    ('fc', 'fc '),
    ('print', 'print '),
    ('cipher /e', 'cipher /e '),
    ('pin', 'pin '),
    ('lang', null),
    ('help', null),
    ('cls', null),
  ];

  @override
  void initState() {
    super.initState();
    WidgetSync.requests.addListener(_onWidgetTap);
    final first = widget.initial;
    if (first != null) WidgetsBinding.instance.addPostFrameCallback((_) => _handleRequest(first));
  }

  @override
  void dispose() {
    WidgetSync.requests.removeListener(_onWidgetTap);
    _ctrl.dispose();
    _focus.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  void _onWidgetTap() {
    final r = WidgetSync.requests.value;
    if (r == null || !mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    _handleRequest(r);
  }

  void _handleRequest(WidgetRequest r) {
    if (!mounted) return;
    final id = r.noteId;
    if (id != null && store.data.byId(id) != null) {
      _openNote(id);
    } else {
      _focus.requestFocus();
    }
  }

  void _run(String raw, {bool fromInput = false}) {
    if (raw.trim().isEmpty) return;
    final out = store.run(raw);
    if (fromInput) _ctrl.clear();
    _histIdx = null;
    _scrollLog();
    if (out == null) return;
    switch (out.route) {
      case 'edit':
        _openNote(out.noteId!);
      case 'encrypt':
        store.encrypt(out.noteId!);
      case 'decrypt':
        _decrypt(out.noteId!);
      case 'fc':
        _focus.unfocus();
        Navigator.of(context).push(termRoute(FcScreen(store: store, noteId: out.noteId!)));
      case 'print':
        _focus.unfocus();
        Navigator.of(context).push(termRoute(PrintScreen(store: store, noteId: out.noteId!)));
      case 'pro' || 'restore':
        _openPro(restore: out.route == 'restore');
      case 'help':
        _focus.unfocus();
        Navigator.of(context).push(termRoute(HelpScreen(store: store)));
      case 'lang':
        _focus.unfocus();
        Navigator.of(context).push(termRoute(LangScreen(store: store)));
    }
  }

  void _scrollLog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) _logScroll.jumpTo(0);
    });
  }

  Future<bool> _confirm(Note n) async {
    if (!n.hidden) return true;
    _focus.unfocus();
    final r = await widget.unlocker.unlock(tr('lock.reason', {'name': n.name}));
    if (r != UnlockResult.ok) store.note(unlockMessage(r), error: r != UnlockResult.cancelled);
    return r == UnlockResult.ok;
  }

  Future<void> _openNote(int id) async {
    if (_busy) return;
    final n = store.data.byId(id);
    if (n == null) return;
    _busy = true;
    int? linkedId;
    try {
      if (!await _confirm(n) || !mounted) return;
      if (n.hidden && await store.unlock(id) == null) {
        store.note(tr('s.dec.fail'), error: true);
        return;
      }
      if (!mounted) return;
      _focus.unfocus();
      linkedId = await Navigator.of(context).push<int>(termRoute(EditorScreen(store: store, noteId: id, reveal: n.hidden)));
      _scrollLog();
    } finally {
      _busy = false;
    }
    if (linkedId != null && mounted) await _openNote(linkedId);
  }

  Future<void> _decrypt(int id) async {
    final n = store.data.byId(id);
    if (n == null || !await _confirm(n)) return;
    await store.decrypt(id);
  }

  void _openPro({bool restore = false}) {
    if (!ProController.supported) {
      store.note(tr('h.proios'));
      return;
    }
    if (restore) store.pro?.restore();
    if (store.pro != null && store.pro!.product == null) store.pro!.loadProduct();
    _focus.unfocus();
    Navigator.of(context).push(termRoute(ProScreen(store: store)));
  }

  void _prefill(String text, {int? cursor}) {
    _ctrl.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor ?? text.length));
    _focus.requestFocus();
  }

  /// 하드웨어 키보드 ↑ ↓ 로 이전 명령어 불러오기.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final up = e.logicalKey == LogicalKeyboardKey.arrowUp;
    final down = e.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!up && !down) return KeyEventResult.ignored;
    final h = store.history;
    if (h.isEmpty) return KeyEventResult.ignored;
    final cur = _histIdx ?? h.length;
    final i = up ? math.max(0, cur - 1) : math.min(h.length, cur + 1);
    _histIdx = i;
    final text = i == h.length ? '' : h[i];
    _ctrl.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    return KeyEventResult.handled;
  }

  Color _logColor(TermPalette p, LogKind k) => switch (k) {
        LogKind.cmd => p.fg,
        LogKind.ok => p.ok,
        LogKind.err => p.warn,
        LogKind.info => p.dim,
        LogKind.text => p.hi,
        LogKind.enc => p.acc,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.palette;
        final list = store.listed;
        final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
        final total = list.where((n) => !n.hidden).fold<int>(0, (s, n) => s + n.bytes);
        final hiddenCount = store.data.notes.where((n) => n.hidden).length;

        return Scaffold(
          backgroundColor: p.bg,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TitleBar(
                palette: p,
                now: store.now(),
                tabs: [
                  if (ProController.supported && !store.isPro) TitleTab('PRO', onTap: _openPro, color: p.tag),
                  TitleTab('dir /a', color: store.showHidden ? p.acc : null, onTap: () => _run(store.showHidden ? 'dir' : 'dir /a')),
                  TitleTab('help', onTap: () => _run('help')),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!typing) ...[
                        Text('NOTEPAD [Version 2.0.0]', style: termStyle(p.hi)),
                        Text(tr('tag'), style: termStyle(p.dim, size: 13)),
                        const SizedBox(height: 12),
                      ],
                      Text.rich(TextSpan(children: [
                        TextSpan(text: '$prompt ', style: termStyle(p.fg)),
                        TextSpan(text: store.showHidden ? 'dir /a' : 'dir', style: termStyle(p.cmd)),
                      ])),
                      const SizedBox(height: 4),
                      Text(tr('h.dir'), style: termStyle(p.dim, size: 12)),
                      const SizedBox(height: 4),
                      Container(height: 1, color: p.line),
                      Expanded(
                        child: list.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text.rich(TextSpan(children: [
                                  TextSpan(text: tr('h.empty1'), style: termStyle(p.dim, size: 13)),
                                  TextSpan(text: 'edit ${tr('x.groc')}', style: termStyle(p.cmd, size: 13)),
                                  TextSpan(text: tr('h.empty2'), style: termStyle(p.dim, size: 13)),
                                ])),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: list.length,
                                itemBuilder: (context, i) => _NoteRow(
                                  key: ValueKey(list[i].id),
                                  note: list[i],
                                  palette: p,
                                  pinned: store.data.pinned == list[i].id,
                                  onTap: () => _openNote(list[i].id),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          tr('h.count', {'n': list.where((n) => !n.hidden).length, 'size': comma(total)}) +
                              (store.showHidden
                                  ? (hiddenCount > 0 ? tr('h.hidden', {'n': hiddenCount}) : '')
                                  : (hiddenCount > 0 ? tr('h.hidden2') : '')),
                          style: termStyle(p.dim, size: 12),
                        ),
                      ),
                      Semantics(
                        liveRegion: true,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: 48, maxHeight: typing ? 96 : 180),
                          child: ListView(
                            controller: _logScroll,
                            reverse: true,
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: [
                              for (final l in store.log.reversed)
                                Text(l.text, style: termStyle(_logColor(p, l.kind), size: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextFieldTapRegion(child: _footer(p)),
            ],
          ),
        );
      },
    );
  }

  Widget _footer(TermPalette p) {
    final question = store.question;
    return Container(
      decoration: BoxDecoration(color: p.bar, border: Border(top: BorderSide(color: p.line))),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (question != null) ...[
              Text(question, style: termStyle(p.warn, size: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: TermBoxButton(palette: p, label: tr('h.del'), textColor: p.warn, onTap: () => _run('y'))),
                  const SizedBox(width: 8),
                  Expanded(child: TermBoxButton(palette: p, label: tr('h.keep'), onTap: () => _run('n'))),
                ],
              ),
            ] else
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (label, fill) in _chips)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: TermBoxButton(
                          palette: p,
                          label: label,
                          textColor: p.cmd,
                          onTap: () => fill == null
                              ? _run(label)
                              : _prefill(fill, cursor: label == 'echo >>' ? 5 : null),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Container(
              height: 50,
              padding: const EdgeInsets.only(left: 12, right: 2),
              decoration: BoxDecoration(color: p.bg, border: Border.all(color: p.line)),
              child: Row(
                children: [
                  Text(question != null ? '(Y/N)>' : prompt, style: termStyle(p.hi)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Focus(
                      onKeyEvent: _onKey,
                      child: Semantics(
                        label: tr('h.sem.input'),
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          style: termStyle(p.hi, size: 16, height: 1.2),
                          cursorColor: p.acc,
                          keyboardAppearance: p.isLight ? Brightness.light : Brightness.dark,
                          cursorWidth: 9,
                          cursorHeight: 18,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration.collapsed(
                            hintText: question != null ? tr('h.hint.yn') : tr('h.hint', {'g': tr('x.groc')}),
                            hintStyle: termStyle(p.dim, size: 16, height: 1.2),
                          ),
                          onChanged: (_) => _histIdx = null,
                          onTapOutside: (_) => _focus.unfocus(),
                          onSubmitted: (v) => _run(v, fromInput: true),
                          onEditingComplete: () {},
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: tr('h.sem.run'),
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () {
                        _run(_ctrl.text, fromInput: true);
                        _focus.requestFocus();
                      },
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(child: CustomPaint(size: const Size(18, 18), painter: ReturnIconPainter(p.acc))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// dir 한 줄: `10-02 16:40  <TXT>  장보기.txt   52`
class _NoteRow extends StatelessWidget {
  const _NoteRow({super.key, required this.note, required this.palette, required this.onTap, this.pinned = false});

  final Note note;
  final TermPalette palette;
  final VoidCallback onTap;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final n = note;
    final kindColor = n.hidden ? p.acc : (n.isLog ? p.tag : p.dim);
    return Semantics(
      button: true,
      label: n.hidden
          ? tr('h.sem.enc', {'name': n.name})
          : tr('h.sem.file', {'name': n.name, 'size': comma(n.bytes), 'when': dirTime(n.modified)}),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: Row(
            children: [
              SizedBox(width: 92, child: Text(dirTime(n.modified), style: termStyle(p.dim, size: 12))),
              SizedBox(width: 52, child: Text(n.kind, style: termStyle(kindColor, size: 12))),
              Expanded(
                child: Text(
                  n.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: termStyle(n.hidden ? p.dim : p.hi, size: 13),
                ),
              ),
              if (pinned) Padding(padding: const EdgeInsets.only(left: 6), child: Text('pin', style: termStyle(p.acc, size: 11))),
              const SizedBox(width: 8),
              Text(n.hidden ? 'AES-256' : comma(n.bytes), style: termStyle(n.hidden ? p.acc : p.dim, size: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
