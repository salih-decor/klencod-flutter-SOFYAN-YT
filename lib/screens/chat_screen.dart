import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/models.dart';
import '../ui/sources_panel.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const String _kAnySubject = 'عام (كل المواد)';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatMessage> _msgs = [];
  String _subject = _kAnySubject;
  bool _useRag = false;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _busy) {
      return;
    }
    final app = context.read<AppState>();
    final userMsg = ChatMessage(role: 'user', content: t);
    setState(() {
      _msgs.add(userMsg);
      _ctrl.clear();
      _busy = true;
      _err = null;
    });
    _scrollEnd();
    try {
      final recent = _msgs.length > 20 ? _msgs.sublist(_msgs.length - 20) : List<ChatMessage>.of(_msgs);
      final r = await app.api.chat(
        recent,
        subject: _subject == _kAnySubject ? null : _subject,
        useRag: _useRag,
      );
      if (!mounted) {
        return;
      }
      setState(() => _msgs.add(ChatMessage(role: 'assistant', content: r.answer, sources: r.sources)));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _msgs.remove(userMsg); // نعيد النص ليُرسل من جديد
          _ctrl.text = t;
          _err = e.message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollEnd();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownField(
                  value: _subject,
                  items: const [_kAnySubject, ...kSubjects],
                  onChanged: (v) => setState(() => _subject = v),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('المكتبة'),
                avatar: const Icon(Icons.local_library_outlined, size: 18),
                selected: _useRag,
                selectedColor: const Color(0x668B5CF6),
                onSelected: (v) => setState(() => _useRag = v),
              ),
              IconButton(
                tooltip: 'محادثة جديدة',
                onPressed: _msgs.isEmpty || _busy ? null : () => setState(() => _msgs.clear()),
                icon: Icon(Icons.delete_sweep_outlined, color: context.textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: _msgs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'اسأل المساعد الدراسي عن أي درس أو تمرين في منهاج السنة الثالثة ثانوي.\n'
                      'فعّل «المكتبة» ليستعين بالملفات التي أضفتَها.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.textMuted, height: 1.8),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: _msgs.length + (_busy ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _msgs.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      );
                    }
                    return _Bubble(msg: _msgs[i]);
                  },
                ),
        ),
        if (_err != null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: ErrorBanner(_err!)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 8000,
                  style: TextStyle(color: context.textMain),
                  decoration: fieldDecoration(context, hint: 'اكتب سؤالك…').copyWith(counterText: ''),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _busy ? null : _send,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    final mine = msg.role == 'user';
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? Brand.violet : context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: mine ? null : Border.all(color: context.cardBorder),
        ),
        child: mine
            ? SelectableText(msg.content, style: const TextStyle(color: Colors.white, height: 1.7, fontSize: 15))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownView(msg.content),
                  SourcesPanel(sources: msg.sources),
                ],
              ),
      ),
    );
  }
}
