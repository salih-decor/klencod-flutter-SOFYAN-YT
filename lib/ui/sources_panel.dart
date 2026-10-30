import 'package:flutter/material.dart';

import '../core/models.dart';
import 'theme.dart';

/// قائمة المراجع المسترجعة من مكتبة التطبيق. تسمّيها «مسترجعة» لا «مستشهَد بها»:
/// النموذج قد لا يستعمل كلها، والمراجعة هي التي تفحص الإسناد.
class SourcesPanel extends StatelessWidget {
  const SourcesPanel({super.key, required this.sources, this.title = 'المراجع المسترجعة من المكتبة'});
  final List<SourceRef> sources;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return const SizedBox.shrink();
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text('$title (${sources.length})',
            style: TextStyle(color: context.textMain, fontWeight: FontWeight.w700, fontSize: 14)),
        children: [
          for (final s in sources)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: context.fieldColor, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '[${s.ref}] ${s.title}${s.page != null ? ' — ص${s.page}' : ''}',
                    style: TextStyle(color: context.textMain, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  if (s.sourceNote != null && s.sourceNote!.isNotEmpty)
                    Text(s.sourceNote!, style: TextStyle(color: context.textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(s.text,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.6)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
