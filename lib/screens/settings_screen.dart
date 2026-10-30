import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url = TextEditingController(text: context.read<AppState>().baseUrl);
  String _status = '';
  bool _ok = true;
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    final app = context.read<AppState>();
    final bad = AppState.validateBaseUrl(_url.text);
    if (bad != null) {
      setState(() {
        _ok = false;
        _status = bad;
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = '';
    });
    await app.setBaseUrl(_url.text);
    try {
      final m = await app.testServer();
      if (mounted) {
        setState(() {
          _ok = true;
          _status = m;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _ok = false;
          _status = e.message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final u = app.user;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('الحساب', style: TextStyle(color: context.textMain, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(u == null ? '—' : '${u.name}\n${u.email}${u.isAdmin ? '\nمشرف' : ''}',
                  style: TextStyle(color: context.textMuted, height: 1.7)),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: GhostButton(icon: Icons.logout, label: 'تسجيل الخروج', onPressed: () => app.logout()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('المظهر', style: TextStyle(color: context.textMain, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('نهاري')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('ليلي')),
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_suggest_outlined), label: Text('النظام')),
                ],
                selected: {app.themeMode},
                onSelectionChanged: (s) => app.setTheme(s.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('خادم SOFYAN YT', style: TextStyle(color: context.textMain, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('مفاتيح الذكاء الاصطناعي وقاعدة البيانات والـ OCR كلها على الخادم، لا داخل التطبيق.',
                  style: TextStyle(color: context.textMuted, fontSize: 12)),
              const SizedBox(height: 10),
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                style: TextStyle(color: context.textMain),
                decoration: fieldDecoration(context, hint: 'https://api.example.com'),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: PrimaryButton(icon: Icons.cloud_done_outlined, label: 'حفظ واختبار الاتصال', busy: _busy, onPressed: _saveAndTest),
              ),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 8),
                if (_ok) NoticeBanner(_status) else ErrorBanner(_status),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Glass(
          child: Text(
            'SOFYAN YT 0.2.0\nالمحتوى المُولَّد بالذكاء الاصطناعي قد يحتوي أخطاء؛ راجع الإجابات مع أستاذك قبل الاعتماد عليها.',
            style: TextStyle(color: context.textMuted, fontSize: 12, height: 1.7),
          ),
        ),
      ],
    );
  }
}
