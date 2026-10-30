import 'package:flutter_test/flutter_test.dart';
import 'package:sofyan_yt/core/app_state.dart';
import 'package:sofyan_yt/core/constants.dart';
import 'package:sofyan_yt/core/models.dart';
import 'package:sofyan_yt/core/pdf_export.dart';

void main() {
  group('إعداد عنوان الخادم', () {
    test('يقبل HTTPS ويرفض http خارج التطوير المحلي', () {
      expect(AppState.validateBaseUrl('https://api.example.com'), isNull);
      expect(AppState.validateBaseUrl('http://example.com'), isNotNull);
      expect(AppState.validateBaseUrl('ftp://x.com'), isNotNull);
      expect(AppState.validateBaseUrl('not a url'), isNotNull);
    });
  });

  group('المهام حسب المادة', () {
    test('الفلسفة تتيح المقالة والاستقصاء', () {
      final keys = tasksFor('الفلسفة').map((t) => t.key).toList();
      expect(keys, containsAll(['exam', 'phil_text', 'phil_essay', 'phil_wad', 'phil_raf']));
      expect(keys, isNot(contains('lit_text')));
    });
    test('العربية تتيح تحليل النص الأدبي فقط إضافة إلى الاختبار', () {
      expect(tasksFor('اللغة العربية وآدابها').map((t) => t.key), ['exam', 'lit_text']);
    });
    test('بقية المواد: الاختبار فقط', () {
      expect(tasksFor('التاريخ').map((t) => t.key), ['exam']);
    });
  });

  group('النماذج', () {
    test('HistoryItem يقرأ سجلًا قديمًا بلا task/sources', () {
      final h = HistoryItem.fromJson({'id': 3, 'subject': 'الفلسفة', 'track': 'x', 'question': 'q', 'answer': 'a'});
      expect(h.task, 'exam');
      expect(h.sources, isEmpty);
      expect(h.review, isNull);
    });
    test('SourceRef.parse', () {
      final s = parseSources([
        {'ref': 'م1', 'title': 'ت', 'page': 4, 'text': 'نص'}
      ]);
      expect(s.single.page, 4);
      expect(parseSources(null), isEmpty);
    });
  });

  test('HTML التصدير: RTL ويهرّب الوسوم', () {
    final html = buildExportHtml(title: 'a<b', subtitle: 's', answer: '**نص** <script>x</script>');
    expect(html, contains('dir="rtl"'));
    expect(html, isNot(contains('<script>')));
    expect(html, contains('a&lt;b'));
  });
}
