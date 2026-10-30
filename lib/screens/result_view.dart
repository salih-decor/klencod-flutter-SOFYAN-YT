import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/models.dart';
import '../core/pdf_export.dart';
import '../ui/sources_panel.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// بيانات نتيجة الحل المعروضة (من الحل الحالي أو من السجل).
class SolveView {
  SolveView({
    required this.id,
    required this.answer,
    required this.subject,
    required this.track,
    required this.task,
    this.review,
    this.sources = const [],
    this.reviewSources = const [],
    this.ragRequested = false,
  });
  final int id;
  final String answer;
  final String subject;
  final String track;
  final String task;
  String? review;
  List<SourceRef> sources;
  List<SourceRef> reviewSources;
  final bool ragRequested;
}

class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.data, required this.busy, required this.onVerify});
  final SolveView data;
  final bool busy;
  final VoidCallback onVerify;

  String get _title => 'SOFYAN YT — ${data.subject}';
  String get _subtitle => 'السنة الثالثة ثانوي — ${data.track} — ${taskLabel(data.task)}';

  String get _html => buildExportHtml(
        title: _title,
        subtitle: _subtitle,
        answer: data.answer,
        review: data.review,
        sources: data.sources,
      );

  void _toast(BuildContext context, String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) {
        _toast(context, 'تعذّر إنشاء PDF: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title, style: TextStyle(color: context.textMain, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(_subtitle, style: TextStyle(color: context.textMuted, fontSize: 13)),
          const SizedBox(height: 4),
          Text('✓ حُفظ الحل تلقائيًا في السجل', style: TextStyle(color: context.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          if (data.ragRequested && data.sources.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: NoticeBanner('طُلبت الاستعانة بالمكتبة لكن لم يُعثر على مقاطع مطابقة؛ الإجابة غير موثّقة بمرجع من المكتبة.'),
            ),
          MarkdownView(data.answer),
          SourcesPanel(sources: data.sources),
          if (data.review != null && data.review!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x1A10B981),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نتيجة إعادة التحقق:',
                      style: TextStyle(color: context.textMain, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  MarkdownView(data.review!),
                  SourcesPanel(sources: data.reviewSources, title: 'مراجع المراجعة'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GhostButton(
                icon: Icons.copy,
                label: 'نسخ',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: data.answer));
                  if (context.mounted) {
                    _toast(context, 'تم النسخ');
                  }
                },
              ),
              GhostButton(
                icon: Icons.verified_user_outlined,
                label: 'إعادة التحقق من الحل',
                onPressed: busy ? null : onVerify,
              ),
              GhostButton(
                icon: Icons.print_outlined,
                label: 'تصدير PDF / طباعة',
                onPressed: () => _run(context, () => previewPdf(_html, name: 'SOFYAN-YT-${data.id}')),
              ),
              GhostButton(
                icon: Icons.share_outlined,
                label: 'مشاركة PDF',
                onPressed: () => _run(context, () => sharePdf(_html, filename: 'SOFYAN-YT-${data.id}.pdf')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
