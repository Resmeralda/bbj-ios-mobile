import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../profile_store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data; replace with Firestore streams.
    return ListenableBuilder(
      listenable: profileStore,
      builder: (context, _) {
        final p = profileStore.profile;
        const done = 3;
        final goal = p.weeklyGoal;
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
                      onPressed: () => context.push('/home/profile'),
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
                      Text('$done of $goal sessions'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ProgressBar(done / goal, AppColors.home),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(done / goal * 100).round()}%',
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
                const Row(
                  children: [
                    _Stat(
                      Icons.sports_martial_arts,
                      '3',
                      'Sessions',
                      AppColors.home,
                    ),
                    _Stat(Icons.schedule, '4.5', 'Hours Trained', Colors.teal),
                    _Stat(
                      Icons.people_alt,
                      '12',
                      'Sparring Rounds',
                      Colors.deepOrange,
                    ),
                    _Stat(
                      Icons.menu_book,
                      '5',
                      'Techniques Practiced',
                      Colors.deepPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const AppCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.track_changes,
                        color: AppColors.home,
                        size: 40,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Next Step',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '1 more session to reach your goal this week!',
                            ),
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
                const SectionHeader('Quick Access', action: 'Edit'),
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
                  onAction: () => context.go('/training'),
                ),
                const _SessionTile(
                  'Tue, Apr 15',
                  'Gi Class',
                  '1.5 hr',
                  '5 rounds',
                  'Guard passing, side control',
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
  const _SessionTile(
    this.date,
    this.title,
    this.hours,
    this.rounds,
    this.notes,
  );

  @override
  Widget build(BuildContext context) => AppCard(
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
              Text(notes, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right),
      ],
    ),
  );
}
