import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late final TextEditingController _url = TextEditingController(text: context.read<AppState>().baseUrl);
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  bool _register = false;
  bool _hide = true;
  bool _busy = false;
  String _err = '';
  String _info = '';

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<bool> _applyUrl() async {
    final bad = AppState.validateBaseUrl(_url.text);
    if (bad != null) {
      setState(() => _err = bad);
      return false;
    }
    await context.read<AppState>().setBaseUrl(_url.text);
    return true;
  }

  Future<void> _test() async {
    setState(() {
      _err = '';
      _info = '';
    });
    if (!await _applyUrl() || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final m = await context.read<AppState>().testServer();
      if (mounted) {
        setState(() => _info = m);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _err = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _err = '';
      _info = '';
    });
    if (!await _applyUrl() || !mounted) {
      return;
    }
    if (_email.text.trim().isEmpty || _pass.text.isEmpty || (_register && _name.text.trim().length < 2)) {
      setState(() => _err = 'أكمل الحقول المطلوبة.');
      return;
    }
    if (_register && _pass.text.length < 8) {
      setState(() => _err = 'كلمة المرور 8 أحرف على الأقل.');
      return;
    }
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      if (_register) {
        await app.register(_email.text, _pass.text, _name.text);
      } else {
        await app.login(_email.text, _pass.text);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _err = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Image.asset('assets/logo.png', width: 84, height: 84)),
                  const SizedBox(height: 10),
                  const Center(child: Wordmark()),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 20),
                      child: Text('المساعد الذكي للبكالوريا الجزائرية', style: TextStyle(color: context.textMuted)),
                    ),
                  ),
                  Glass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('تسجيل الدخول')),
                            ButtonSegment(value: true, label: Text('حساب جديد')),
                          ],
                          selected: {_register},
                          onSelectionChanged: (s) => setState(() {
                            _register = s.first;
                            _err = '';
                          }),
                        ),
                        const SizedBox(height: 14),
                        if (_register) ...[
                          TextField(
                            controller: _name,
                            style: TextStyle(color: context.textMain),
                            decoration: fieldDecoration(context, hint: 'الاسم'),
                          ),
                          const SizedBox(height: 10),
                        ],
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(color: context.textMain),
                          decoration: fieldDecoration(context, hint: 'البريد الإلكتروني'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _pass,
                          obscureText: _hide,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(color: context.textMain),
                          onSubmitted: (_) => _submit(),
                          decoration: fieldDecoration(context, hint: 'كلمة المرور').copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => _hide = !_hide),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        PrimaryButton(
                          label: _register ? 'إنشاء الحساب' : 'دخول',
                          icon: Icons.login,
                          busy: _busy,
                          onPressed: _submit,
                        ),
                        if (_err.isNotEmpty) ...[const SizedBox(height: 10), ErrorBanner(_err)],
                        if (_info.isNotEmpty) ...[const SizedBox(height: 10), NoticeBanner(_info)],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Glass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('عنوان الخادم (HTTPS)', style: TextStyle(color: context.textMuted, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _url,
                          keyboardType: TextInputType.url,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(color: context.textMain),
                          decoration: fieldDecoration(context, hint: 'https://api.example.com'),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: GhostButton(icon: Icons.cloud_done_outlined, label: 'اختبار الاتصال', onPressed: _busy ? null : _test),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
