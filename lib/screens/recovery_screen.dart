import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) => ScreenScaffold(
    title: 'Recovery',
    color: AppColors.recovery,
    actionIcon: Icons.settings,
    tabs: const ['Overview', 'Sleep', 'Wellness', 'Notes'],
    tab: tab,
    onTab: (i) => setState(() => tab = i), // TODO: build other tabs
    children: [
      const AppCard(
        child: Row(
          children: [
            Icon(Icons.nightlight_round, color: AppColors.recovery, size: 36),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sleep Last Night', style: TextStyle(fontSize: 12)),
                  Text(
                    '7 hr 30 min',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Goal: 8 hr', style: TextStyle(fontSize: 12)),
                  ProgressBar(7.5 / 8, AppColors.recovery),
                ],
              ),
            ),
          ],
        ),
      ),
      const SectionHeader('Recovery Score', action: 'View Details'),
      AppCard(
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: 0.82,
                      strokeWidth: 12,
                      color: Colors.green,
                      backgroundColor: Colors.black12,
                    ),
                  ),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '82',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Good', style: TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                children: [
                  _Metric(Icons.nightlight_round, 'Sleep', '7.5 hr'),
                  _Metric(Icons.favorite, 'HRV', '68 ms'),
                  _Metric(Icons.bolt, 'Energy', 'Good'),
                  _Metric(Icons.accessibility_new, 'Soreness', 'Low'),
                  _Metric(Icons.emoji_emotions, 'Overall', 'Good'),
                ],
              ),
            ),
          ],
        ),
      ),
      Row(
        children: [
          QuickTile(Icons.bed, 'Log Sleep', AppColors.recovery, onTap: () {}),
          QuickTile(Icons.favorite, 'Log Wellness', Colors.red, onTap: () {}),
          QuickTile(
            Icons.self_improvement,
            'Mobility / Stretching',
            Colors.blue,
            onTap: () {},
          ),
          QuickTile(
            Icons.note_add,
            'Add Note',
            Colors.amber.shade800,
            onTap: () {},
          ),
        ],
      ),
      const SizedBox(height: 12),
      const AppCard(
        child: Row(
          children: [
            Icon(Icons.checklist, color: AppColors.recovery, size: 32),
            SizedBox(width: 12),
            Text(
              'Recovery Habits',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('3 of 5 completed', style: TextStyle(fontSize: 12)),
                  ProgressBar(3 / 5, AppColors.recovery),
                ],
              ),
            ),
          ],
        ),
      ),
      const SectionHeader('This Week', action: 'View All'),
      const Row(
        children: [
          _Trend('7.2 hr', 'Avg Sleep', AppColors.recovery, [
            7,
            6,
            8,
            7,
            7.5,
            6.5,
            7.5,
          ]),
          _Trend('Good', 'Avg Energy', Colors.green, [4, 3, 5, 4, 5, 4, 5]),
          _Trend('Low', 'Avg Soreness', Colors.orange, [4, 5, 3, 2, 1, 2, 1]),
          _Trend('68 ms', 'Avg HRV', Colors.blue, [60, 65, 70, 68, 72, 66, 68]),
        ],
      ),
      const SectionHeader('Recent Notes', action: 'View All'),
      const AppCard(
        child: Row(
          children: [
            Icon(Icons.description, color: AppColors.recovery, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tue, Apr 15',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  Text(
                    'Feeling good',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Slept well, light soreness. Did some stretching.'),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Metric(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.recovery),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        Text(value, style: const TextStyle(color: AppColors.muted)),
      ],
    ),
  );
}

class _Trend extends StatelessWidget {
  final String value, label;
  final Color color;
  final List<double> data;
  const _Trend(this.value, this.label, this.color, this.data);

  @override
  Widget build(BuildContext context) {
    final max = data.reduce((a, b) => a > b ? a : b);
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final d in data)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          height: 36 * d / max,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
