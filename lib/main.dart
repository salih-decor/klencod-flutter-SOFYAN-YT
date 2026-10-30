import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/constants.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const SofyanApp(),
    ),
  );
}

class SofyanApp extends StatelessWidget {
  const SofyanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      builder: (context, child) => AppBackground(child: child ?? const SizedBox.shrink()),
      home: const _Gate(),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final ready = context.select<AppState, bool>((s) => s.ready);
    final loggedIn = context.select<AppState, bool>((s) => s.loggedIn);
    if (!ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return loggedIn ? const HomeShell() : const AuthScreen();
  }
}