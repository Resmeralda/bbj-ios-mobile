import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/training_session.dart';
import '../session_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/session_tile.dart';

/// Standalone history page (route /training/history).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Training History'),
      backgroundColor: AppColors.training,
      foregroundColor: Colors.white,
    ),
    floatingActionButton: FloatingActionButton(
      backgroundColor: AppColors.home,
      foregroundColor: Colors.white,
      onPressed: () => context.push('/training/log'),
      child: const Icon(Icons.add),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: const [HistoryBody()],
    ),
  );
}

/// History content, reused inline by the Training tab.
class HistoryBody extends StatefulWidget {
  const HistoryBody({super.key});
  @override
  State<HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<HistoryBody> {
  String filter = 'All';

  Future<bool> _confirmDelete(TrainingSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text('${s.type} on ${formatDate(s.date)} will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _deleted(TrainingSession s) {
    sessionStore.delete(s.id);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Session deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => sessionStore.add(s),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sessionStore,
    builder: (context, _) {
      final all = sessionStore.sessions;
      final list = filter == 'All'
          ? all
          : all.where((s) => s.type == filter).toList();
      final hours = list.fold<double>(0, (a, s) => a + s.hours);
      final rounds = list.fold<int>(0, (a, s) => a + s.rounds);

      final items = <Widget>[];
      int? lastKey;
      for (final s in list) {
        final key = s.date.year * 100 + s.date.month;
        if (key != lastKey) {
          items.add(
            SectionHeader('${monthNames[s.date.month - 1]} ${s.date.year}'),
          );
          lastKey = key;
        }
        items.add(
          Dismissible(
            key: ValueKey(s.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDelete(s),
            onDismissed: (_) => _deleted(s),
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.only(right: 20),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: SessionTile(
              s,
              onTap: () => context.push('/training/log', extra: s),
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            color: AppColors.tint,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Total('${list.length}', 'Sessions'),
                _Total(hours.toStringAsFixed(1), 'Hours'),
                _Total('$rounds', 'Rounds'),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in ['All', ...sessionTypes])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: filter == f,
                      onSelected: (_) => setState(() => filter = f),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No sessions yet. Tap + to log one.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ),
          ...items,
        ],
      );
    },
  );
}

class _Total extends StatelessWidget {
  final String value, label;
  const _Total(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.home,
        ),
      ),
      Text(label, style: const TextStyle(color: AppColors.muted)),
    ],
  );
}
