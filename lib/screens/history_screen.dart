import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/models.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.active, required this.onOpen});

  /// true عندما يكون التبويب ظاهرًا (لإعادة التحميل عند فتحه).
  final bool active;
  final void Function(HistoryItem item) onOpen;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryRow> _rows = const [];
  bool _loading = true;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HistoryScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _load();
    }
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final r = await app.api.history();
      if (mounted) {
        setState(() => _rows = r);
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

  Future<void> _open(HistoryRow r) async {
    final app = context.read<AppState>();
    try {
      final item = await app.api.historyItem(r.id);
      if (mounted) {
        widget.onOpen(item);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _err = e.message);
      }
    }
  }

  Future<void> _delete(HistoryRow r) async {
    final app = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحل'),
        content: const Text('سيُحذف هذا الحل نهائيًا من السجل.'),
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
      await app.api.historyDelete(r.id);
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
          if (_err.isNotEmpty) ErrorBanner(_err),
          if (_loading && _rows.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_rows.isEmpty && _err.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text('لا توجد حلول محفوظة بعد.',
                  textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
            ),
          for (final r in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Glass(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _open(r),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${r.subject} — ${r.track}',
                                  style: TextStyle(color: context.textMain, fontWeight: FontWeight.w700)),
                              Text(taskLabel(r.task), style: TextStyle(color: context.textMuted, fontSize: 12)),
                              Text(formatDate(r.created), style: TextStyle(color: context.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () => _delete(r),
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
