import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

/// عنوان الخادم الافتراضي يُحقن وقت البناء:  --dart-define=API_BASE_URL=https://api.example.com
const String kDefaultBaseUrl = String.fromEnvironment('API_BASE_URL');

class AppState extends ChangeNotifier {
  AppState() {
    api = ApiClient(
      baseUrl: () => baseUrl,
      token: () => token,
      onUnauthorized: _onUnauthorized,
    );
  }

  late final ApiClient api;
  final FlutterSecureStorage _secure =
      const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  SharedPreferences? _prefs;

  bool ready = false;
  ThemeMode themeMode = ThemeMode.dark;
  String baseUrl = '';
  String? token;
  AppUser? user;

  bool get loggedIn => token != null && baseUrl.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    switch (prefs.getString('theme')) {
      case 'light':
        themeMode = ThemeMode.light;
      case 'system':
        themeMode = ThemeMode.system;
      default:
        themeMode = ThemeMode.dark;
    }
    baseUrl = prefs.getString('base_url') ?? kDefaultBaseUrl;
    try {
      token = await _secure.read(key: 'token');
    } catch (_) {
      token = null; // تعذّر فك التشفير (مثلاً بعد استعادة نسخة احتياطية)
    }
    final rawUser = prefs.getString('user');
    if (rawUser != null) {
      try {
        user = AppUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
      } catch (_) {
        user = null;
      }
    }
    ready = true;
    notifyListeners();
    if (loggedIn) {
      try {
        user = await api.me();
        await prefs.setString('user', jsonEncode(user!.toJson()));
        notifyListeners();
      } catch (_) {
        // 401 يعالجه onUnauthorized؛ بقية الأخطاء (لا إنترنت) نتجاهلها ونبقي الجلسة.
      }
    }
  }

  /// يتحقق من صلاحية العنوان: HTTPS إلزامي في نسخة release.
  static String? validateBaseUrl(String raw) {
    final v = raw.trim();
    final u = Uri.tryParse(v);
    if (u == null || u.host.isEmpty || !(u.scheme == 'https' || u.scheme == 'http')) {
      return 'أدخل عنوانًا صحيحًا مثل https://api.example.com';
    }
    if (u.scheme == 'http') {
      final local = u.host == '10.0.2.2' || u.host == 'localhost' || u.host == '127.0.0.1';
      if (!(kDebugMode && local)) {
        return 'يجب استعمال HTTPS (http مسموح فقط لخادم محلي في نسخة التطوير).';
      }
    }
    return null;
  }

  Future<void> setBaseUrl(String raw) async {
    var v = raw.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    baseUrl = v;
    await _prefs?.setString('base_url', v);
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    await _prefs?.setString('theme', m == ThemeMode.light ? 'light' : (m == ThemeMode.system ? 'system' : 'dark'));
    notifyListeners();
  }

  Future<void> _saveSession(AuthResult r) async {
    token = r.token;
    user = r.user;
    try {
      await _secure.write(key: 'token', value: r.token);
    } catch (_) {
      // إن فشل التخزين الآمن تبقى الجلسة في الذاكرة فقط.
    }
    await _prefs?.setString('user', jsonEncode(r.user.toJson()));
    notifyListeners();
  }

  Future<void> login(String email, String password) async =>
      _saveSession(await api.login(email.trim(), password));

  Future<void> register(String email, String password, String name) async =>
      _saveSession(await api.register(email.trim(), password, name.trim()));

  Future<void> logout() async {
    token = null;
    user = null;
    try {
      await _secure.delete(key: 'token');
    } catch (_) {}
    await _prefs?.remove('user');
    notifyListeners();
  }

  /// اختبار الاتصال بالخادم (يرمي ApiException عند الفشل).
  Future<String> testServer() async {
    final h = await api.health();
    final llm = h['llm_configured'] == true;
    return 'الخادم متصل ✓ — مفتاح الذكاء الاصطناعي: ${llm ? 'مضبوط' : 'غير مضبوط على الخادم'}';
  }

  void _onUnauthorized() {
    if (token != null) {
      logout();
    }
  }
}
