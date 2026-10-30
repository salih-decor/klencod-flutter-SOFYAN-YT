import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/models.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'result_view.dart';

const int _maxFiles = 8;
const int _maxBytes = 10 * 1024 * 1024;

class SolveScreen extends StatefulWidget {
  const SolveScreen({super.key, this.opened, this.openedSerial = 0});

  /// حل مفتوح من السجل (يُحمَّل عند تغيّر openedSerial).
  final HistoryItem? opened;
  final int openedSerial;

  @override
  State<SolveScreen> createState() => _SolveScreenState();
}

class _SolveScreenState extends State<SolveScreen> {
  final List<String> _files = [];
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _track = kTracks.first;
  String _subject = kSubjects.first;
  String _task = 'exam';
  String _mode = 'model';
  bool _useRag = false;
  String _stage = '';
  String _notice = '';
  String _err = '';
  SolveView? _res;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant SolveScreen old) {
    super.didUpdateWidget(old);
    final h = widget.opened;
    if (h != null && widget.openedSerial != old.openedSerial) {
      setState(() {
        _text.text = h.question;
        _subject = kSubjects.contains(h.subject) ? h.subject : kSubjects.last;
        _track = kTracks.contains(h.track) ? h.track : kTracks.first;
        _task = tasksFor(_subject).any((t) => t.key == h.task) ? h.task : 'exam';
        _res = SolveView(
          id: h.id,
          answer: h.answer,
          subject: h.subject,
          track: h.track,
          task: h.task,
          review: h.review,
          sources: h.sources,
        );
        _err = '';
        _notice = '';
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _busy => _stage.isNotEmpty;

  Future<void> _run(String label, Future<void> Function() fn) async {
    setState(() {
      _err = '';
      _stage = label;
    });
    try {
      await fn();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _err = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _err = 'حدث خطأ غير متوقع: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _stage = '');
      }
    }
  }

  Future<void> _addFiles(Iterable<String> paths) async {
    final msgs = <String>[];
    for (final p in paths) {
      if (_files.length >= _maxFiles) {
        msgs.add('الحد الأقصى $_maxFiles ملفات.');
        break;
      }
      final size = await File(p).length();
      if (size > _maxBytes) {
        msgs.add('تم تجاهل ملف أكبر من 10MB.');
        continue;
      }
      if (!_files.contains(p)) {
        _files.add(p);
      }
    }
    if (mounted) {
      setState(() => _err = msgs.join(' '));
    }
  }

  Future<void> _pickCamera() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 92, maxWidth: 2800);
      if (x != null) {
        await _addFiles([x.path]);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _err = 'تعذّر فتح الكاميرا: $e');
      }
    }
  }

  Future<void> _pickGallery() async {
    try {
      final xs = await ImagePicker().pickMultiImage(imageQuality: 92, maxWidth: 2800);
      await _addFiles(xs.map((e) => e.path));
    } catch (e) {
      if (mounted) {
        setState(() => _err = 'تعذّر فتح المعرض: $e');
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: true,
      );
      if (r != null) {
        await _addFiles(r.paths.whereType<String>());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _err = 'تعذّر اختيار الملفات: $e');
      }
    }
  }

  Future<void> _doOcr() async {
    final app = context.read<AppState>();
    await _run('قراءة الملفات واستخراج الأسئلة…', () async {
      final r = await app.api.ocr(List.of(_files));
      if (!mounted) {
        return;
      }
      setState(() {
        _text.text = r.text;
        if (r.warning != null) {
          _notice = r.warning!;
        } else if (r.fromTextLayer) {
          _notice = 'استُخرج النص مباشرة من ملف PDF — راجعه قبل الحل.';
        } else {
          _notice = 'متوسط وضوح القراءة ≈ ${r.meanConf}% — راجع النص قبل الحل.';
        }
      });
    });
  }

  Future<void> _doSolve() async {
    final app = context.read<AppState>();
    final text = _text.text;
    final subject = _subject;
    final track = _track;
    final task = _task;
    final useRag = _useRag;
    await _run('إنشاء الحل…', () async {
      final r = await app.api.solve(
        text: text,
        subject: subject,
        track: track,
        task: task,
        mode: _mode,
        useRag: useRag,
      );
      if (!mounted) {
        return;
      }
      setState(() => _res = SolveView(
            id: r.id,
            answer: r.answer,
            subject: subject,
            track: track,
            task: task,
            sources: r.sources,
            ragRequested: useRag,
          ));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    });
  }

  Future<void> _doVerify() async {
    final res = _res;
    if (res == null) {
      return;
    }
    final app = context.read<AppState>();
    await _run('مراجعة الإجابة…', () async {
      final r = await app.api.verify(res.id);
      if (!mounted) {
        return;
      }
      setState(() {
        res.review = r.review;
        res.reviewSources = r.sources;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasks = tasksFor(_subject);
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('حل اختبار بالذكاء الاصطناعي',
                  style: TextStyle(color: context.textMain, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GhostButton(icon: Icons.photo_camera_outlined, label: 'تصوير', onPressed: _busy ? null : _pickCamera),
                  GhostButton(icon: Icons.photo_library_outlined, label: 'من المعرض', onPressed: _busy ? null : _pickGallery),
                  GhostButton(icon: Icons.attach_file, label: 'PDF / صور', onPressed: _busy ? null : _pickFiles),
                ],
              ),
              if (_files.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _files.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _Thumb(
                      path: _files[i],
                      onRemove: _busy ? null : () => setState(() => _files.removeAt(i)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GhostButton(
                  icon: Icons.document_scanner_outlined,
                  label: 'استخراج النص من الملفات',
                  onPressed: _busy ? null : _doOcr,
                ),
              ],
              if (_notice.isNotEmpty) ...[const SizedBox(height: 8), NoticeBanner(_notice)],
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                minLines: 8,
                maxLines: 16,
                style: TextStyle(color: context.textMain),
                decoration: fieldDecoration(context, hint: 'النص المستخرج (قابل للتعديل) أو الصق نص الاختبار هنا…'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownField(
                      label: 'الشعبة',
                      value: _track,
                      items: kTracks,
                      onChanged: (v) => setState(() => _track = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownField(
                      label: 'المادة',
                      value: _subject,
                      items: kSubjects,
                      onChanged: (v) => setState(() {
                        _subject = v;
                        if (!tasksFor(v).any((t) => t.key == _task)) {
                          _task = 'exam';
                        }
                      }),
                    ),
                  ),
                ],
              ),
              if (tasks.length > 1) ...[
                const SizedBox(height: 12),
                Text('نوع المهمة', style: TextStyle(color: context.textMuted, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final t in tasks)
                      ChoiceChip(
                        label: Text(t.label),
                        selected: _task == t.key,
                        selectedColor: const Color(0x668B5CF6),
                        onSelected: (_) => setState(() => _task = t.key),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'model', label: Text('الإجابة النموذجية')),
                  ButtonSegment(value: 'teacher', icon: Icon(Icons.psychology_outlined), label: Text('الأستاذ الذكي')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _useRag,
                onChanged: (v) => setState(() => _useRag = v),
                title: Text('الاستعانة بمكتبة المراجع (RAG)', style: TextStyle(color: context.textMain, fontSize: 14)),
                subtitle: Text('يبحث في ملفاتك والملفات المشتركة ويُلحق المقاطع المطابقة بالسؤال',
                    style: TextStyle(color: context.textMuted, fontSize: 12)),
              ),
              const SizedBox(height: 4),
              PrimaryButton(
                icon: Icons.auto_awesome,
                label: 'حل الاختبار',
                busy: _busy,
                onPressed: _text.text.trim().length < 5 ? null : _doSolve,
              ),
              if (_busy) ...[
                const SizedBox(height: 10),
                Text(_stage, textAlign: TextAlign.center, style: const TextStyle(color: Brand.violetLight)),
              ],
              if (_err.isNotEmpty) ...[const SizedBox(height: 10), ErrorBanner(_err)],
            ],
          ),
        ),
        if (_res != null) ...[
          const SizedBox(height: 16),
          ResultView(data: _res!, busy: _busy, onVerify: _doVerify),
        ],
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path, required this.onRemove});
  final String path;
  final VoidCallback? onRemove;

  bool get _isPdf => path.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _isPdf
              ? Container(
                  width: 84,
                  height: 84,
                  color: context.chipColor,
                  child: Icon(Icons.picture_as_pdf, color: context.textMain, size: 36),
                )
              : Image.file(
                  File(path),
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  cacheWidth: 240,
                  errorBuilder: (_, __, ___) => Container(
                    width: 84,
                    height: 84,
                    color: context.chipColor,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
        ),
        PositionedDirectional(
          top: 2,
          end: 2,
          child: InkWell(
            onTap: onRemove,
            child: const CircleAvatar(radius: 11, backgroundColor: Color(0xCC000000), child: Icon(Icons.close, size: 14, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
