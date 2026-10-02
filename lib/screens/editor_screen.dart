import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/commands.dart';
import '../logic/notes.dart';
import '../state/notepad_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';

/// `edit 장보기` 화면. 쓰는 대로 저장된다.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.store, required this.noteId});

  final NotepadStore store;
  final int noteId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();
  Timer? _savedTimer;
  bool _saved = true;
  bool _closing = false;

  /// 잠긴 메모: 앱 전환 화면에 내용이 보이지 않게 가린다.
  bool _cover = false;

  NotepadStore get store => widget.store;
  Note? get _note => store.data.byId(widget.noteId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // .LOG 메모면 열 때 맨 끝에 지금 시간이 찍힌다.
    final opened = store.open(widget.noteId);
    final text = opened?.text ?? '';
    _ctrl = TextEditingController(text: text);
    _ctrl.selection = TextSelection.collapsed(offset: text.length);
    if (text.isEmpty || (opened?.isLog ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _savedTimer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hidden = _note?.hidden ?? false;
    if (state == AppLifecycleState.resumed) {
      if (_cover) setState(() => _cover = false);
      return;
    }
    store.updateText(widget.noteId, _ctrl.text);
    store.flush();
    if (!hidden) return;
    if (state == AppLifecycleState.inactive && !_cover) setState(() => _cover = true);
    // 잠긴 메모는 앱을 나가면 닫는다: 다시 열려면 Face ID.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _close();
  }

  void _onChanged(String text) {
    store.updateText(widget.noteId, text);
    if (_saved) setState(() => _saved = false);
    _savedTimer?.cancel();
    _savedTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _saved = true);
    });
  }

  /// F5: 커서 자리에 지금 시간 (옛 메모장처럼)
  void _stamp() {
    final stamp = logStamp(store.now());
    final sel = _ctrl.selection;
    final text = _ctrl.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(start, end, stamp);
    _ctrl.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: start + stamp.length));
    _onChanged(next);
    _focus.requestFocus();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    store.updateText(widget.noteId, _ctrl.text);
    store.closed(widget.noteId);
    // PopScope 가 막는 건 뒤로 가기 제스처뿐: 여기서는 바로 닫는다.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.palette;
        final note = _note;
        final text = _ctrl.text;
        final lines = text.isEmpty ? 1 : '\n'.allMatches(text).length + 1;
        final isLog = text.split('\n').first.trim() == '.LOG';
        return PopScope(
          canPop: _closing,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _close();
          },
          child: Scaffold(
            backgroundColor: p.bg,
            body: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TitleBar(palette: p, now: store.now()),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(children: [
                                      TextSpan(text: '$prompt ', style: termStyle(p.fg, size: 13)),
                                      TextSpan(text: 'edit ${note?.name ?? ''}', style: termStyle(p.cmd, size: 13)),
                                    ]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(_saved ? '✓ 저장됨' : '저장 중...', style: termStyle(_saved ? p.ok : p.dim, size: 12)),
                              ],
                            ),
                            if (isLog || (note?.hidden ?? false)) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (note?.hidden ?? false) '잠긴 파일 · 앱을 나가면 닫혀요',
                                  if (isLog) '.LOG · 열 때마다 시간이 찍혀요',
                                ].join('  ·  '),
                                style: termStyle(note?.hidden ?? false ? p.acc : p.tag, size: 12),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                decoration: BoxDecoration(border: Border.all(color: p.line)),
                                child: Semantics(
                                  label: '${note?.name ?? '메모'} 내용',
                                  child: TextField(
                                    controller: _ctrl,
                                    focusNode: _focus,
                                    expands: true,
                                    maxLines: null,
                                    minLines: null,
                                    textAlignVertical: TextAlignVertical.top,
                                    keyboardType: TextInputType.multiline,
                                    style: termStyle(p.hi, size: 15, height: 1.6),
                                    cursorColor: p.acc,
                                    keyboardAppearance: p.isLight ? Brightness.light : Brightness.dark,
                                    decoration: InputDecoration.collapsed(
                                      hintText: '여기에 쓰면 바로 저장돼요',
                                      hintStyle: termStyle(p.dim, size: 15, height: 1.6),
                                    ),
                                    onChanged: _onChanged,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '줄 $lines · ${comma(note?.bytes ?? 0)} 바이트',
                                    style: termStyle(p.dim, size: 12),
                                  ),
                                ),
                                Text('UTF-8', style: termStyle(p.dim, size: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TermWideButton(palette: p, keyLabel: '[ ESC ]', label: '닫기', onTap: _close),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 52,
                                child: TermBoxButton(
                                  palette: p,
                                  label: 'F5 시간',
                                  textColor: p.cmd,
                                  semanticLabel: '커서 자리에 지금 시간 넣기',
                                  onTap: _stamp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_cover) Positioned.fill(child: ColoredBox(color: p.bg)),
              ],
            ),
          ),
        );
      },
    );
  }
}
