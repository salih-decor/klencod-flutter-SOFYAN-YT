import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'models.dart';

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;');

String _md(String s) => md.markdownToHtml(_esc(s), extensionSet: md.ExtensionSet.gitHubFlavored);

/// يبني صفحة HTML عربية RTL تُحوَّل إلى PDF عبر محرك WebView في النظام
/// (لذلك يعمل ربط الحروف العربية واتجاه RTL دون تضمين خطوط).
String buildExportHtml({
  required String title,
  required String subtitle,
  required String answer,
  String? review,
  List<SourceRef> sources = const [],
}) {
  final b = StringBuffer()
    ..writeln('<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">')
    ..writeln('<style>')
    ..writeln('@page{size:A4;margin:15mm}')
    ..writeln('body{direction:rtl;font-family:"Noto Naskh Arabic","Noto Sans Arabic",sans-serif;color:#000;background:#fff;line-height:1.9;font-size:14px}')
    ..writeln('h1{font-size:22px;margin:0}h2{font-size:18px}h3{font-size:16px}')
    ..writeln('.sub{color:#444;margin-bottom:12px}')
    ..writeln('table{border-collapse:collapse;width:100%}td,th{border:1px solid #888;padding:4px 8px}')
    ..writeln('.box{border:1px solid #999;border-radius:8px;padding:8px 12px;margin-top:16px;page-break-inside:avoid}')
    ..writeln('.src{font-size:12px;color:#333;margin:4px 0}')
    ..writeln('code,pre{direction:ltr;text-align:left}')
    ..writeln('</style></head><body>')
    ..writeln('<h1>${_esc(title)}</h1><div class="sub">${_esc(subtitle)}</div>')
    ..writeln(_md(answer));
  if (review != null && review.trim().isNotEmpty) {
    b.writeln('<div class="box"><b>نتيجة إعادة التحقق:</b>${_md(review)}</div>');
  }
  if (sources.isNotEmpty) {
    b.writeln('<div class="box"><b>مراجع مسترجعة من المكتبة:</b>');
    for (final s in sources) {
      final pg = s.page != null ? ' — ص${s.page}' : '';
      b.writeln('<div class="src">[${_esc(s.ref)}] ${_esc(s.title)}$pg</div>');
    }
    b.writeln('</div>');
  }
  b.writeln('</body></html>');
  return b.toString();
}

/// معاينة الطباعة (من هناك: «حفظ كـ PDF» أو طباعة أو مشاركة).
Future<void> previewPdf(String html, {String name = 'SOFYAN-YT'}) {
  return Printing.layoutPdf(
    name: name,
    onLayout: (PdfPageFormat format) => Printing.convertHtml(format: format, html: html),
  );
}

/// ينشئ ملف PDF ويشاركه مباشرة.
Future<void> sharePdf(String html, {String filename = 'SOFYAN-YT.pdf'}) async {
  final bytes = await Printing.convertHtml(format: PdfPageFormat.a4, html: html);
  await Printing.sharePdf(bytes: bytes, filename: filename);
}
