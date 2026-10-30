const String kAppName = 'SOFYAN YT';
const String kTagline = 'المساعد الذكي للبكالوريا الجزائرية';

const List<String> kTracks = [
  'آداب وفلسفة',
  'لغات أجنبية',
  'علوم تجريبية',
  'رياضيات',
  'تقني رياضي',
  'تسيير واقتصاد',
];

const List<String> kSubjects = [
  'الفلسفة',
  'اللغة العربية وآدابها',
  'التاريخ',
  'الجغرافيا',
  'العلوم الإسلامية',
  'اللغة الفرنسية',
  'اللغة الإنجليزية',
  'الرياضيات',
  'مادة أخرى',
];

class TaskType {
  const TaskType(this.key, this.label, this.subject);
  final String key;
  final String label;

  /// null = متاحة لكل المواد.
  final String? subject;
}

/// المفاتيح تطابق backend/prompts.py → TASKS
const List<TaskType> kTasks = [
  TaskType('exam', 'حل الاختبار (كل الأسئلة)', null),
  TaskType('phil_text', 'تحليل نص فلسفي', 'الفلسفة'),
  TaskType('phil_essay', 'مقالة جدلية', 'الفلسفة'),
  TaskType('phil_wad', 'استقصاء بالوضع', 'الفلسفة'),
  TaskType('phil_raf', 'استقصاء بالرفع', 'الفلسفة'),
  TaskType('lit_text', 'تحليل نص أدبي (بناء فكري ولغوي)', 'اللغة العربية وآدابها'),
];

List<TaskType> tasksFor(String subject) =>
    kTasks.where((t) => t.subject == null || t.subject == subject).toList();

String taskLabel(String key) {
  for (final t in kTasks) {
    if (t.key == key) {
      return t.label;
    }
  }
  return 'حل الاختبار';
}

String formatDate(double epochSeconds) {
  final d = DateTime.fromMillisecondsSinceEpoch((epochSeconds * 1000).round());
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
}
