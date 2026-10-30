import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// عميل REST لخادم FastAPI. العنوان والرمز يُقرآن عند كل طلب من AppState.
class ApiClient {
  ApiClient({required this.baseUrl, required this.token, required this.onUnauthorized});

  final String Function() baseUrl;
  final String? Function() token;
  final void Function() onUnauthorized;

  static const Duration _timeout = Duration(seconds: 180);

  Uri _uri(String path, [Map<String, String>? query]) {
    var b = baseUrl().trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    if (b.isEmpty) {
      throw ApiException('لم يُضبط عنوان الخادم. افتح «إعدادات الخادم» وأدخل عنوان HTTPS.');
    }
    final u = Uri.parse('$b$path');
    return query == null ? u : u.replace(queryParameters: query);
  }

  Map<String, String> _headers({bool json = true}) {
    final t = token();
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json; charset=utf-8',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  String? _detail(dynamic body) {
    if (body is Map && body['detail'] != null) {
      final d = body['detail'];
      if (d is String) {
        return d;
      }
      if (d is List && d.isNotEmpty) {
        final f = d.first;
        if (f is Map && f['msg'] != null) {
          return 'بيانات غير صالحة: ${f['msg']}';
        }
      }
    }
    return null;
  }

  Future<dynamic> _handle(Future<http.Response> Function() call, {bool auth = true}) async {
    http.Response r;
    try {
      r = await call().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('انتهت مهلة الاتصال بالخادم.');
    } on HandshakeException {
      throw ApiException('فشل التحقق من شهادة HTTPS للخادم.');
    } on SocketException {
      throw ApiException('تعذر الاتصال بالخادم. تحقق من الإنترنت ومن عنوان الخادم.');
    } on http.ClientException catch (e) {
      throw ApiException('تعذر الاتصال بالخادم (${e.message}).');
    }
    dynamic body;
    final text = utf8.decode(r.bodyBytes, allowMalformed: true);
    if (text.isNotEmpty) {
      try {
        body = jsonDecode(text);
      } catch (_) {
        body = null;
      }
    }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return body;
    }
    if (r.statusCode == 401 && auth) {
      onUnauthorized();
    }
    throw ApiException(_detail(body) ?? 'خطأ من الخادم (${r.statusCode})', r.statusCode);
  }

  Future<dynamic> _get(String path, {Map<String, String>? query, bool auth = true}) =>
      _handle(() => http.get(_uri(path, query), headers: _headers(json: false)), auth: auth);

  Future<dynamic> _post(String path, Object? body, {bool auth = true}) => _handle(
      () => http.post(_uri(path), headers: _headers(), body: body == null ? null : jsonEncode(body)),
      auth: auth);

  Future<dynamic> _delete(String path) =>
      _handle(() => http.delete(_uri(path), headers: _headers(json: false)));

  Future<dynamic> _multipart(String path, Map<String, String> fields, String fileField, List<String> paths) {
    return _handle(() async {
      final req = http.MultipartRequest('POST', _uri(path));
      req.headers.addAll(_headers(json: false));
      req.fields.addAll(fields);
      for (final p in paths) {
        req.files.add(await http.MultipartFile.fromPath(fileField, p));
      }
      final streamed = await req.send();
      return http.Response.fromStream(streamed);
    });
  }

  Map<String, dynamic> _map(dynamic b) {
    if (b is Map<String, dynamic>) {
      return b;
    }
    throw ApiException('رد غير متوقع من الخادم.');
  }

  // ── عام ──
  Future<Map<String, dynamic>> health() async => _map(await _get('/api/health', auth: false));

  // ── الحسابات ──
  AuthResult _auth(dynamic b) {
    final m = _map(b);
    return AuthResult(m['token'] as String, AppUser.fromJson(m['user'] as Map<String, dynamic>));
  }

  Future<AuthResult> register(String email, String password, String name) async =>
      _auth(await _post('/api/auth/register', {'email': email, 'password': password, 'name': name}, auth: false));

  Future<AuthResult> login(String email, String password) async =>
      _auth(await _post('/api/auth/login', {'email': email, 'password': password}, auth: false));

  Future<AppUser> me() async => AppUser.fromJson(_map(await _get('/api/auth/me')));

  // ── OCR والحل ──
  Future<OcrResult> ocr(List<String> paths) async =>
      OcrResult.fromJson(_map(await _multipart('/api/ocr', {}, 'files', paths)));

  Future<SolveResult> solve({
    required String text,
    required String subject,
    required String track,
    required String task,
    required String mode,
    required bool useRag,
  }) async =>
      SolveResult.fromJson(_map(await _post('/api/solve', {
        'text': text,
        'subject': subject,
        'track': track,
        'task': task,
        'mode': mode,
        'use_rag': useRag,
      })));

  Future<VerifyResult> verify(int id, {bool useRag = true}) async =>
      VerifyResult.fromJson(_map(await _post('/api/verify/$id', {'use_rag': useRag})));

  Future<ChatReply> chat(List<ChatMessage> messages, {String? subject, String? track, bool useRag = false}) async {
    final m = _map(await _post('/api/chat', {
      'messages': messages.map((e) => e.toJson()).toList(),
      if (subject != null) 'subject': subject,
      if (track != null) 'track': track,
      'use_rag': useRag,
    }));
    return ChatReply(m['answer'] as String, parseSources(m['sources']));
  }

  // ── السجل ──
  Future<List<HistoryRow>> history() async {
    final b = await _get('/api/history');
    if (b is! List) {
      return const [];
    }
    return b.whereType<Map<String, dynamic>>().map(HistoryRow.fromJson).toList();
  }

  Future<HistoryItem> historyItem(int id) async => HistoryItem.fromJson(_map(await _get('/api/history/$id')));

  Future<void> historyDelete(int id) async {
    await _delete('/api/history/$id');
  }

  // ── المكتبة ──
  Future<List<LibDoc>> library() async {
    final b = await _get('/api/library');
    if (b is! List) {
      return const [];
    }
    return b.whereType<Map<String, dynamic>>().map(LibDoc.fromJson).toList();
  }

  Future<List<SourceRef>> librarySearch(String q, {String? subject}) async {
    final b = await _get('/api/library/search', query: {'q': q, if (subject != null) 'subject': subject});
    return parseSources(b);
  }

  Future<void> libraryUpload(
    String path, {
    required String title,
    String subject = '',
    String track = '',
    String year = '',
    String sourceNote = '',
    bool shared = false,
  }) async {
    await _multipart(
      '/api/library',
      {
        'title': title,
        'subject': subject,
        'track': track,
        'year': year,
        'source_note': sourceNote,
        'shared': shared ? 'true' : 'false',
      },
      'file',
      [path],
    );
  }

  Future<void> libraryDelete(int id) async {
    await _delete('/api/library/$id');
  }
}
