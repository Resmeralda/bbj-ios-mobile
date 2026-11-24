import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/training_session.dart';
import '../profile_store.dart';
import '../session_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/form_helpers.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.store, this.sessions});

  final ProfileStore? store;
  final SessionStore? sessions;

  @override
  Widget build(BuildContext context) {
    final profiles = store ?? profileStore;
    final training = sessions ?? sessionStore;
    return ListenableBuilder(
      listenable: Listenable.merge([profiles, training]),
      builder: (context, _) {
        final p = profiles.profile;
        final account = training.account;
        final week = training.thisWeek;
        final done = week.length;
        final goal = p.weeklyGoal;
        final progress = (done / goal).clamp(0.0, 1.0);
        final hours = week.fold(0.0, (total, session) => total + session.hours);
        final rounds = week.fold(0, (total, session) => total + session.rounds);
        final techniques = week
            .expand((session) => session.techniques.split(','))
            .map((name) => name.trim().toLowerCase())
            .where((name) => name.isNotEmpty)
            .toSet()
            .length;
        final unavailable = training.loading || training.error != null;
        final remaining = goal - done;
        final nextStep = training.loading
            ? 'Loading your training sessions…'
            : training.error ??
                  (remaining <= 0
                      ? 'You reached your weekly goal!'
                      : '$remaining more ${remaining == 1 ? 'session' : 'sessions'} to reach your goal this week!');
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi, ${p.name}!',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Keep showing up 🌿',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/home/profile'),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.tint,
                        child: Text(
                          p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            color: AppColors.home,
                          ),
                        ),
                      ), // TODO: Firebase Storage photo
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.settings, color: AppColors.muted),
                      tooltip: 'Profile settings',
                      onPressed: () => context.push('/home/profile/edit'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppCard(
                  color: AppColors.tint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weekly Progress',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        unavailable
                            ? '— of $goal sessions'
                            : '$done of $goal sessions',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ProgressBar(
                              unavailable ? 0 : progress,
                              AppColors.home,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            unavailable ? '—' : '${(progress * 100).round()}%',
                            style: const TextStyle(
                              color: AppColors.home,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _Stat(
                      Icons.sports_martial_arts,
                      unavailable ? '—' : '$done',
                      'Sessions',
                      AppColors.home,
                    ),
                    _Stat(
                      Icons.schedule,
                      unavailable ? '—' : hours.toStringAsFixed(1),
                      'Hours Trained',
                      Colors.teal,
                    ),
                    _Stat(
                      Icons.people_alt,
                      unavailable ? '—' : '$rounds',
                      'Sparring Rounds',
                      Colors.deepOrange,
                    ),
                    _Stat(
                      Icons.menu_book,
                      unavailable ? '—' : '$techniques',
                      'Techniques Practiced',
                      Colors.deepPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.track_changes,
                        color: AppColors.home,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Next Step',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(nextStep),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.home,
                    padding: const EdgeInsets.all(18),
                  ),
                  onPressed: () => context.push('/training/log'),
                  icon: const Icon(Icons.add),
                  label: const Text('Log Training Session'),
                ),
                const SizedBox(height: 16),
                const SectionHeader('Quick Access'),
                Row(
                  children: [
                    QuickTile(
                      Icons.fitness_center,
                      'Training Log',
                      AppColors.home,
                      onTap: () => context.go('/training'),
                    ),
                    QuickTile(
                      Icons.menu_book,
                      'Techniques',
                      AppColors.home,
                      onTap: () => context.go('/training/techniques'),
                    ),
                    QuickTile(
                      Icons.rice_bowl,
                      'Nutrition',
                      AppColors.home,
                      onTap: () => context.go('/nutrition'),
                    ),
                    QuickTile(
                      Icons.nightlight_round,
                      'Recovery',
                      AppColors.home,
                      onTap: () => context.go('/recovery'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionHeader(
                  'This Week',
                  action: 'View All',
                  onAction: () => context.push('/training/history'),
                ),
                if (!unavailable && week.isEmpty)
                  const AppCard(child: Text('No training sessions this week.')),
                if (!unavailable)
                  for (final session in week.take(3))
                    _SessionTile(
                      formatDate(session.date.toLocal()),
                      session.type,
                      formatHours(session.hours),
                      '${session.rounds} rounds',
                      [
                        session.techniques,
                        session.notes,
                      ].where((text) => text.isNotEmpty).join(' • '),
                      onTap: () {
                        if (isCurrentFormAccount(
                          context,
                          account,
                          training.account,
                        )) {
                          context.push('/training/log', extra: session);
                        }
                      },
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _Stat(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SessionTile extends StatelessWidget {
  final String date, title, hours, rounds, notes;
  final VoidCallback onTap;
  const _SessionTile(
    this.date,
    this.title,
    this.hours,
    this.rounds,
    this.notes, {
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.image_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$hours  •  $rounds',
                style: const TextStyle(color: AppColors.muted),
              ),
              if (notes.isNotEmpty)
                Text(notes, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right),
      ],
    ),
  );
}
