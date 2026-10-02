import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/commands.dart';
import '../logic/notes.dart';
import '../state/notepad_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';

/// 공유 이미지의 모양
class PrintLook {
  const PrintLook({
    required this.id,
    required this.card,
    required this.face,
    required this.faceInk,
    required this.title,
    required this.titleInk,
    required this.paper,
    required this.ink,
    required this.edge,
  });

  final String id;
  final Color card, face, faceInk, title, titleInk, paper, ink, edge;

  static const retro = PrintLook(
    id: 'retro',
    card: Color(0xFF3A6EA5),
    face: Color(0xFFC9CCC4),
    faceInk: Color(0xFF111111),
    title: Color(0xFF1F3D7A),
    titleInk: Color(0xFFFFFFFF),
    paper: Color(0xFFFFFFFF),
    ink: Color(0xFF111111),
    edge: Color(0xFF7A7A7A),
  );
  static const cmd = PrintLook(
    id: 'cmd',
    card: Color(0xFF0C0C0C),
    face: Color(0xFF1A1A1A),
    faceInk: Color(0xFF8A8A8A),
    title: Color(0xFF2A2A2A),
    titleInk: Color(0xFFF2F2F2),
    paper: Color(0xFF0C0C0C),
    ink: Color(0xFFF2F2F2),
    edge: Color(0xFF2A2A2A),
  );
  static const paperLook = PrintLook(
    id: 'paper',
    card: Color(0xFFE8E4D6),
    face: Color(0xFFF5F2E8),
    faceInk: Color(0xFF6B6B6B),
    title: Color(0xFF2B2B2B),
    titleInk: Color(0xFFF5F2E8),
    paper: Color(0xFFFBF9F4),
    ink: Color(0xFF2B2B2B),
    edge: Color(0xFFD6D1C2),
  );
  static const all = [retro, cmd, paperLook];
}

/// `print 장보기`: 메모를 옛날 컴퓨터 창 모양 이미지(1080 x 1350)로 저장 · 공유.
class PrintScreen extends StatefulWidget {
  const PrintScreen({super.key, required this.store, required this.noteId});

  final NotepadStore store;
  final int noteId;

  @override
  State<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> {
  static const _cardW = 300.0, _cardH = 375.0;
  final _cardKey = GlobalKey();
  PrintLook _look = PrintLook.retro;
  bool _busy = false;
  String? _msg;
  bool _msgIsError = false;

  NotepadStore get store => widget.store;

  String _fileName(Note n) {
    final base = n.name.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '').replaceAll(RegExp(r'\s+'), '-');
    return 'notepad-exe-$base';
  }

  Future<Uint8List> _render() async {
    final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1080 / _cardW);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _save(Note n) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) {
          _say('access denied: photos\n설정 > notepad.exe 에서 사진 추가를 허용해 주세요.', error: true);
          return;
        }
      }
      await Gal.putImageBytes(await _render(), name: _fileName(n));
      _say('✓ saved to C:\\PICS\\${_fileName(n)}.png');
      HapticFeedback.mediumImpact();
    } on GalException catch (e) {
      _say('save failed: ${e.type.message}', error: true);
    } catch (e) {
      _say('save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(Note n) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _render();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_fileName(n)}.png');
      await file.writeAsBytes(png, flush: true);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      _say('share failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String msg, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _msg = msg;
      _msgIsError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = store.palette;
    final n = store.data.byId(widget.noteId);
    if (n == null || n.hidden) {
      return Scaffold(backgroundColor: p.bg, body: Column(children: [TitleBar(palette: p, now: store.now())]));
    }
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitleBar(palette: p, now: store.now()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: '$prompt ', style: termStyle(p.fg, size: 13)),
                  TextSpan(text: 'print ${n.name}', style: termStyle(p.cmd, size: 13)),
                  TextSpan(text: '  1080x1350', style: termStyle(p.ok, size: 13)),
                ])),
                const SizedBox(height: 12),
                Center(
                  child: Semantics(
                    label: '${n.name} 메모장 창 이미지 미리보기',
                    image: true,
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: SizedBox(width: _cardW, height: _cardH, child: NoteCard(note: n, look: _look)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final l in PrintLook.all)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: l == PrintLook.all.last ? 0 : 6),
                          child: TermBoxButton(
                            palette: p,
                            label: l.id,
                            selected: l.id == _look.id,
                            textColor: p.cmd,
                            onTap: () => setState(() {
                              _look = l;
                              _msg = null;
                            }),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: SizedBox(
                    height: 36,
                    child: Text(_msg ?? '', style: termStyle(_msgIsError ? p.warn : p.ok, size: 12)),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  Expanded(child: TermBoxButton(palette: p, label: 'SAVE .PNG', textColor: p.ok, onTap: () => _save(n))),
                  const SizedBox(width: 8),
                  Expanded(child: TermBoxButton(palette: p, label: 'SHARE', onTap: () => _share(n))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TermBoxButton(palette: p, label: 'CLOSE', onTap: () => Navigator.of(context).maybePop()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 공유 이미지 한 장: 바탕 + 옛날 컴퓨터 창 + 메모 + 워터마크 (4:5)
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.look});

  final Note note;
  final PrintLook look;

  static const _maxLines = 13;

  @override
  Widget build(BuildContext context) {
    final l = look;
    final lines = note.text.split('\n');
    final shown = lines.length > _maxLines ? [...lines.take(_maxLines - 1), '…'] : lines;
    TextStyle mono(Color c, double size, {FontWeight w = FontWeight.w400, double h = 1.3}) =>
        termStyle(c, size: size, weight: w, height: h);
    Widget box(String t) => Container(
          width: 14,
          height: 12,
          alignment: Alignment.center,
          color: l.face,
          child: Text(t, style: mono(l.faceInk, 8, h: 1)),
        );
    return Container(
      color: l.card,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: l.face,
                boxShadow: const [BoxShadow(color: Color(0x8C000000), offset: Offset(5, 5))],
              ),
              padding: const EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 20,
                    color: l.title,
                    padding: const EdgeInsets.only(left: 6, right: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${note.name} - notepad.exe',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mono(l.titleInk, 9.5, w: FontWeight.w700, h: 1),
                          ),
                        ),
                        box('_'),
                        const SizedBox(width: 2),
                        box('x'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
                    child: Text('파일   편집   보기   도움말', style: mono(l.faceInk, 8.5, h: 1.2)),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                      decoration: BoxDecoration(color: l.paper, border: Border.all(color: l.edge)),
                      child: Text(
                        shown.join('\n'),
                        overflow: TextOverflow.clip,
                        style: mono(l.ink, 10.5, h: 1.55),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 2, 6, 1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('줄 ${note.lines} · ${comma(note.bytes)} 바이트', style: mono(l.faceInk, 8, h: 1.2)),
                        Text(dirTime(note.modified), style: mono(l.faceInk, 8, h: 1.2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('C:\\> notepad.exe', style: mono(l.id == 'retro' ? const Color(0xFFDDE6F2) : l.faceInk, 9, h: 1)),
        ],
      ),
    );
  }
}
