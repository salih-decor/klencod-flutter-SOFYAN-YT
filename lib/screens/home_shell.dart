import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../ui/widgets.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'solve_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  HistoryItem? _opened;
  int _serial = 0;

  void _open(HistoryItem item) {
    setState(() {
      _opened = item;
      _serial++;
      _index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Header(
              trailing: IconButton(
                tooltip: dark ? 'الوضع النهاري' : 'الوضع الليلي',
                onPressed: () => app.setTheme(dark ? ThemeMode.light : ThemeMode.dark),
                icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  SolveScreen(opened: _opened, openedSerial: _serial),
                  const ChatScreen(),
                  LibraryScreen(active: _index == 2),
                  HistoryScreen(active: _index == 3, onOpen: _open),
                  const SettingsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: keyboardOpen
          ? null
          : NavigationBar(
              selectedIndex: _index,
              backgroundColor: dark ? const Color(0xF20B1230) : Colors.white,
              indicatorColor: const Color(0x668B5CF6),
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'حل'),
                NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'المساعد'),
                NavigationDestination(icon: Icon(Icons.local_library_outlined), selectedIcon: Icon(Icons.local_library), label: 'المكتبة'),
                NavigationDestination(icon: Icon(Icons.history), label: 'السجل'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
              ],
            ),
    );
  }
}
