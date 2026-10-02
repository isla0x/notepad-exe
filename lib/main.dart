import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';

import 'lock.dart';
import 'note_cipher.dart';
import 'pro/pro_controller.dart';
import 'screens/boot_screen.dart';
import 'screens/home_screen.dart';
import 'state/notepad_store.dart';
import 'theme/term_palette.dart';
import 'widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 암호화(cipher)는 OS 의 암호화 기능(iOS CryptoKit)으로: 직접 만든 암호 코드를 쓰지 않는다.
  FlutterCryptography.enable();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final pro = ProController();
  await pro.init();
  final store = NotepadStore(pro: pro, cipher: KeychainCipher());
  await store.load();
  store.systemBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;

  // 위젯은 메모 · PRO 상태가 바뀌면 새로 그린다. 글자를 칠 때마다가 아니라 잠깐 모았다가.
  final fromWidget = await WidgetSync.init();
  Timer? widgetTimer;
  void pushWidget() => WidgetSync.push(store.data, store.now(), pro: store.isPro);
  pushWidget();
  store.addListener(() {
    widgetTimer?.cancel();
    widgetTimer = Timer(const Duration(milliseconds: 1200), pushWidget);
  });

  runApp(NotepadExeApp(store: store, unlocker: DeviceUnlocker(), fromWidget: fromWidget));
}

class NotepadExeApp extends StatefulWidget {
  const NotepadExeApp({super.key, required this.store, required this.unlocker, this.fromWidget});

  final NotepadStore store;
  final Unlocker unlocker;

  /// 위젯을 눌러서 켜졌으면 부팅 화면 없이 바로 그 메모(또는 입력칸)로.
  final WidgetRequest? fromWidget;

  @override
  State<NotepadExeApp> createState() => _NotepadExeAppState();
}

class _NotepadExeAppState extends State<NotepadExeApp> with WidgetsBindingObserver {
  NotepadStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    store.systemBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) store.refresh();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) store.flush();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.palette;
        return MaterialApp(
          title: 'notepad.exe',
          debugShowCheckedModeBanner: false,
          theme: _theme(p),
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: (p.isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light).copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: p.bar,
              systemNavigationBarIconBrightness: p.isLight ? Brightness.dark : Brightness.light,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          home: widget.fromWidget != null
              ? HomeScreen(store: store, unlocker: widget.unlocker, initial: widget.fromWidget)
              : BootScreen(store: store, unlocker: widget.unlocker),
        );
      },
    );
  }

  ThemeData _theme(TermPalette p) => ThemeData(
        useMaterial3: true,
        brightness: p.isLight ? Brightness.light : Brightness.dark,
        scaffoldBackgroundColor: p.bg,
        fontFamily: monoFamily,
        fontFamilyFallback: monoFallback,
        colorScheme: p.isLight
            ? ColorScheme.light(surface: p.bg, primary: p.acc, secondary: p.cmd, error: p.warn)
            : ColorScheme.dark(surface: p.bg, primary: p.acc, secondary: p.cmd, error: p.warn),
        splashFactory: NoSplash.splashFactory,
        highlightColor: p.fg.withAlpha(30),
        hoverColor: p.fg.withAlpha(16),
        focusColor: p.cmd.withAlpha(48),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: p.acc,
          selectionColor: p.acc.withAlpha(90),
          selectionHandleColor: p.acc,
        ),
      );
}
