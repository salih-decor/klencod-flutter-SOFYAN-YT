class AppUser {
  const AppUser({required this.id, required this.email, required this.name, required this.isAdmin});
  final int id;
  final String email;
  final String name;
  final bool isAdmin;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num).toInt(),
        email: j['email'] as String,
        name: j['name'] as String,
        isAdmin: j['is_admin'] == true,
      );

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'name': name, 'is_admin': isAdmin};
}

class AuthResult {
  const AuthResult(this.token, this.user);
  final String token;
  final AppUser user;
}

class OcrResult {
  const OcrResult({required this.text, required this.meanConf, required this.warning, required this.fromTextLayer});
  final String text;
  final double? meanConf;
  final String? warning;
  final bool fromTextLayer;

  factory OcrResult.fromJson(Map<String, dynamic> j) => OcrResult(
        text: (j['text'] ?? '') as String,
        meanConf: (j['mean_conf'] as num?)?.toDouble(),
        warning: j['warning'] as String?,
        fromTextLayer: j['from_text_layer'] == true,
      );
}

class SourceRef {
  const SourceRef({required this.ref, required this.title, required this.page, required this.text, this.sourceNote});
  final String ref;
  final String title;
  final int? page;
  final String text;
  final String? sourceNote;

  factory SourceRef.fromJson(Map<String, dynamic> j) => SourceRef(
        ref: (j['ref'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        page: (j['page'] as num?)?.toInt(),
        text: (j['text'] ?? '') as String,
        sourceNote: j['source_note'] as String?,
      );
}

List<SourceRef> parseSources(dynamic raw) {
  if (raw is! List) {
    return const [];
  }
  return raw.whereType<Map<String, dynamic>>().map(SourceRef.fromJson).toList();
}

class SolveResult {
  const SolveResult({required this.id, required this.answer, required this.sources});
  final int id;
  final String answer;
  final List<SourceRef> sources;

  factory SolveResult.fromJson(Map<String, dynamic> j) => SolveResult(
        id: (j['id'] as num).toInt(),
        answer: j['answer'] as String,
        sources: parseSources(j['sources']),
      );
}

class VerifyResult {
  const VerifyResult({required this.review, required this.sources});
  final String review;
  final List<SourceRef> sources;

  factory VerifyResult.fromJson(Map<String, dynamic> j) =>
      VerifyResult(review: j['review'] as String, sources: parseSources(j['sources']));
}

class ChatReply {
  const ChatReply(this.answer, this.sources);
  final String answer;
  final List<SourceRef> sources;
}

class ChatMessage {
  ChatMessage({required this.role, required this.content, this.sources = const []});
  final String role; // user | assistant
  final String content;
  final List<SourceRef> sources;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class HistoryRow {
  const HistoryRow({required this.id, required this.created, required this.subject, required this.track, required this.task});
  final int id;
  final double created;
  final String subject;
  final String track;
  final String task;

  factory HistoryRow.fromJson(Map<String, dynamic> j) => HistoryRow(
        id: (j['id'] as num).toInt(),
        created: (j['created'] as num).toDouble(),
        subject: (j['subject'] ?? '') as String,
        track: (j['track'] ?? '') as String,
        task: (j['task'] ?? 'exam') as String,
      );
}

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.subject,
    required this.track,
    required this.task,
    required this.question,
    required this.answer,
    required this.review,
    required this.sources,
  });
  final int id;
  final String subject;
  final String track;
  final String task;
  final String question;
  final String answer;
  final String? review;
  final List<SourceRef> sources;

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        id: (j['id'] as num).toInt(),
        subject: (j['subject'] ?? '') as String,
        track: (j['track'] ?? '') as String,
        task: (j['task'] ?? 'exam') as String,
        question: (j['question'] ?? '') as String,
        answer: (j['answer'] ?? '') as String,
        review: j['review'] as String?,
        sources: parseSources(j['sources']),
      );
}

class LibDoc {
  const LibDoc({
    required this.id,
    required this.title,
    required this.subject,
    required this.track,
    required this.year,
    required this.sourceNote,
    required this.pages,
    required this.chunks,
    required this.shared,
    required this.mine,
  });
  final int id;
  final String title;
  final String? subject;
  final String? track;
  final String? year;
  final String? sourceNote;
  final int pages;
  final int chunks;
  final bool shared;
  final bool mine;

  factory LibDoc.fromJson(Map<String, dynamic> j) => LibDoc(
        id: (j['id'] as num).toInt(),
        title: (j['title'] ?? '') as String,
        subject: j['subject'] as String?,
        track: j['track'] as String?,
        year: j['year'] as String?,
        sourceNote: j['source_note'] as String?,
        pages: (j['pages'] as num?)?.toInt() ?? 0,
        chunks: (j['chunks'] as num?)?.toInt() ?? 0,
        shared: j['shared'] == true,
        mine: j['mine'] == true,
      );
}
