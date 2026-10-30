import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/models.dart';
import '../ui/sources_panel.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const String _kUnset = 'غير محدد';

class _UploadMeta {
  _UploadMeta(this.title, this.subject, this.track, this.year, this.note, this.shared);
  final String title;
  final String subject;
  final String track;
  final String year;
  final String note;
  final bool shared;
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.active});
  final bool active;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<LibDoc> _docs = const [];
  List<SourceRef>? _hits;
  bool _loading = true;
  bool _busy = false;
  String _err = '';
  String _msg = '';
  final TextEditingController _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LibraryScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _load();
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final d = await app.api.library();
      if (mounted) {
        setState(() => _docs = d);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _err = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _search() async {
    final q = _q.text.trim();
    if (q.length < 2) {
      setState(() => _hits = null);
      return;
    }
    final app = context.read<AppState>();
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final h = await app.api.librarySearch(q);
      if (mounted) {
        setState(() => _hits = h);
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

  Future<void> _upload() async {
    final app = context.read<AppState>();
    final isAdmin = app.user?.isAdmin ?? false;
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'txt', 'md'],
    );
    final path = r?.files.single.path;
    if (path == null || !mounted) {
      return;
    }
    final name = r!.files.single.name;
    final meta = await showDialog<_UploadMeta>(
      context: context,
      builder: (ctx) => _UploadDialog(defaultTitle: name.replaceAll(RegExp(r'\.[^.]+$'), ''), isAdmin: isAdmin),
    );
    if (meta == null) {
      return;
    }
    setState(() {
      _busy = true;
      _err = '';
      _msg = 'جارٍ رفع الملف وفهرسته (قد يستغرق دقائق للملفات الممسوحة)…';
    });
    try {
      await app.api.libraryUpload(
        path,
        title: meta.title,
        subject: meta.subject,
        track: meta.track,
        year: meta.year,
        sourceNote: meta.note,
        shared: meta.shared,
      );
      if (mounted) {
        setState(() => _msg = 'تمت الإضافة والفهرسة.');
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _err = e.message;
          _msg = '';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete(LibDoc d) async {
    final app = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملف'),
        content: Text('سيُحذف «${d.title}» وفهرسه نهائيًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await app.api.libraryDelete(d.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _err = e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _q,
                  style: TextStyle(color: context.textMain),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: fieldDecoration(context, hint: 'ابحث في مراجعك…'),
                ),
              ),
              IconButton(onPressed: _busy ? null : _search, icon: Icon(Icons.search, color: context.textMain)),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PrimaryButton(icon: Icons.upload_file, label: 'إضافة ملف إلى المكتبة', busy: _busy, onPressed: _upload),
          ),
          if (_msg.isNotEmpty) ...[const SizedBox(height: 8), NoticeBanner(_msg)],
          if (_err.isNotEmpty) ...[const SizedBox(height: 8), ErrorBanner(_err)],
          const SizedBox(height: 12),
          if (_hits != null) ...[
            Row(
              children: [
                Expanded(
                    child: Text('نتائج البحث (${_hits!.length})',
                        style: TextStyle(color: context.textMain, fontWeight: FontWeight.w800))),
                TextButton(onPressed: () => setState(() => _hits = null), child: const Text('إغلاق')),
              ],
            ),
            if (_hits!.isEmpty)
              Text('لا توجد نتائج مطابقة.', style: TextStyle(color: context.textMuted))
            else
              Glass(child: SourcesPanel(sources: _hits!, title: 'المقاطع المطابقة')),
            const SizedBox(height: 12),
          ],
          if (_loading && _docs.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_docs.isEmpty && _err.isEmpty)
            Glass(
              child: Text(
                'المكتبة فارغة.\n'
                'لا يتضمن التطبيق أي مراجع أو اختبارات جاهزة. أضف ملفات (PDF أو صور أو نص) من مصادر موثوقة، '
                'مثل مواضيع الامتحانات السابقة والكتب المدرسية التي لديك حق استعمالها، وسيبحث فيها المساعد '
                'عند تفعيل «الاستعانة بمكتبة المراجع».',
                style: TextStyle(color: context.textMuted, height: 1.8),
              ),
            ),
          for (final d in _docs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Glass(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Row(
                  children: [
                    Icon(d.shared ? Icons.public : Icons.lock_outline, color: context.textMuted, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.title, style: TextStyle(color: context.textMain, fontWeight: FontWeight.w700)),
                          Text(
                            [
                              if (d.subject != null && d.subject!.isNotEmpty) d.subject!,
                              if (d.track != null && d.track!.isNotEmpty) d.track!,
                              if (d.year != null && d.year!.isNotEmpty) d.year!,
                              if (d.pages > 0) '${d.pages} صفحة',
                              '${d.chunks} مقطع',
                              d.shared ? 'مشترك' : 'خاص',
                            ].join(' • '),
                            style: TextStyle(color: context.textMuted, fontSize: 12),
                          ),
                          if (d.sourceNote != null && d.sourceNote!.isNotEmpty)
                            Text(d.sourceNote!, style: TextStyle(color: context.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (d.mine || (context.read<AppState>().user?.isAdmin ?? false))
                      IconButton(
                        tooltip: 'حذف',
                        onPressed: () => _delete(d),
                        icon: Icon(Icons.delete_outline, color: context.textMuted),
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

class _UploadDialog extends StatefulWidget {
  const _UploadDialog({required this.defaultTitle, required this.isAdmin});
  final String defaultTitle;
  final bool isAdmin;

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  late final TextEditingController _title = TextEditingController(text: widget.defaultTitle);
  final TextEditingController _year = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String _subject = _kUnset;
  String _track = _kUnset;
  bool _shared = false;

  @override
  void dispose() {
    _title.dispose();
    _year.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('بيانات الملف'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'العنوان')),
            const SizedBox(height: 8),
            DropdownField(label: 'المادة', value: _subject, items: const [_kUnset, ...kSubjects], onChanged: (v) => setState(() => _subject = v)),
            const SizedBox(height: 8),
            DropdownField(label: 'الشعبة', value: _track, items: const [_kUnset, ...kTracks], onChanged: (v) => setState(() => _track = v)),
            const SizedBox(height: 8),
            TextField(controller: _year, decoration: const InputDecoration(labelText: 'السنة (اختياري)')),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'مصدر الملف (اختياري)', hintText: 'مثال: موقع/كتاب/جهة النشر'),
            ),
            if (widget.isAdmin)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _shared,
                onChanged: (v) => setState(() => _shared = v),
                title: const Text('مشترك مع كل المستخدمين'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        TextButton(
          onPressed: () {
            final t = _title.text.trim();
            if (t.isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _UploadMeta(
                t,
                _subject == _kUnset ? '' : _subject,
                _track == _kUnset ? '' : _track,
                _year.text.trim(),
                _note.text.trim(),
                _shared,
              ),
            );
          },
          child: const Text('رفع'),
        ),
      ],
    );
  }
}
