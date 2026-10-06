import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../session_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/session_tile.dart';
import 'history_screen.dart' show HistoryBody;
import 'techniques_screen.dart' show TechniquesContent;

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});
  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  int tab = 0; // 0 Log, 1 History, 2 Techniques
  int selectedDay = DateTime.now().weekday - 1;
  static const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sessionStore,
    builder: (context, _) {
      final now = DateTime.now();
      final monday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      final all = sessionStore.sessions;
      bool trained(DateTime d) => all.any(
        (s) =>
            s.date.year == d.year &&
            s.date.month == d.month &&
            s.date.day == d.day,
      );

      return ScreenScaffold(
        title: 'Training',
        color: AppColors.training,
        actionIcon: Icons.add,
        onAction: () => context.push('/training/log'),
        tabs: const ['Log', 'History', 'Techniques'],
        tab: tab,
        onTab: (i) => setState(() => tab = i),
        children: tab == 1
            ? const [HistoryBody()]
            : tab == 2
            ? const [TechniquesContent()]
            : [
                AppCard(
                  color: AppColors.tint,
                  onTap: () => context.push('/training/log'),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        color: AppColors.home,
                        size: 36,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Log a Training Session',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Track your mat time, techniques, and progress.',
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                const SectionHeader('This Week'),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Builder(
                        builder: (context) {
                          final d = monday.add(Duration(days: i));
                          final sel = i == selectedDay;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => selectedDay = i),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: sel ? AppColors.home : Colors.black12,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      days[i],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: sel
                                            ? Colors.white
                                            : AppColors.muted,
                                      ),
                                    ),
                                    Text(
                                      '${d.day}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: sel
                                            ? Colors.white
                                            : AppColors.ink,
                                      ),
                                    ),
                                    Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: sel
                                          ? Colors.white
                                          : trained(d)
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionHeader(
                  'Recent Sessions',
                  action: 'View All',
                  onAction: () => setState(() => tab = 1),
                ),
                if (all.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No sessions yet.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                for (final s in all.take(3))
                  SessionTile(
                    s,
                    onTap: () => context.push('/training/log', extra: s),
                  ),
                const SectionHeader('Quick Add'),
                Row(
                  children: [
                    QuickTile(
                      Icons.sports_martial_arts,
                      'Gi Class',
                      AppColors.home,
                      onTap: () => context.push('/training/log'),
                    ),
                    QuickTile(
                      Icons.checkroom,
                      'No-Gi Class',
                      Colors.deepPurple,
                      onTap: () => context.push('/training/log'),
                    ),
                    QuickTile(
                      Icons.people_alt,
                      'Open Mat',
                      Colors.deepOrange,
                      onTap: () => context.push('/training/log'),
                    ),
                    QuickTile(
                      Icons.fitness_center,
                      'Drilling / Technique',
                      Colors.amber.shade800,
                      onTap: () => context.push('/training/log'),
                    ),
                  ],
                ),
              ],
      );
    },
  );
}
