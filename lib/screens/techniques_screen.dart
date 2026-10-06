import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// Standalone techniques page (route /training/techniques).
class TechniquesScreen extends StatefulWidget {
  const TechniquesScreen({super.key});
  @override
  State<TechniquesScreen> createState() => _TechniquesScreenState();
}

class _TechniquesScreenState extends State<TechniquesScreen> {
  int tab = 0;
  static const filters = [
    'All',
    'Takedowns',
    'Submissions',
    'Guard',
    'Escapes',
  ];

  @override
  Widget build(BuildContext context) => ScreenScaffold(
    title: 'Techniques',
    color: AppColors.techniques,
    actionIcon: Icons.search,
    tabs: filters,
    tab: tab,
    onTab: (i) =>
        setState(() => tab = i), // TODO: filter Firestore query by category
    children: const [TechniquesContent()],
  );
}

/// Techniques content, reused inline by the Training tab.
class TechniquesContent extends StatelessWidget {
  const TechniquesContent({super.key});

  @override
  Widget build(BuildContext context) {
    void _open(String name) =>
        context.push('/training/techniques/${Uri.encodeComponent(name)}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          color: Colors.blueGrey.shade700,
          onTap: () => _open('Armbar from Guard'),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Featured Technique',
                style: TextStyle(color: Colors.white70),
              ),
              const Text(
                'Armbar from Guard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'A fundamental submission everyone should know.',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.ink,
                ),
                onPressed: () => _open('Armbar from Guard'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Watch Video'),
              ),
            ],
          ),
        ),
        Row(
          children: [
            QuickTile(Icons.people_alt, 'Takedowns\n24 techniques', Colors.red),
            QuickTile(
              Icons.sports_kabaddi,
              'Submissions\n37 techniques',
              Colors.blue,
            ),
            QuickTile(
              Icons.self_improvement,
              'Guard\n28 techniques',
              Colors.green,
            ),
            QuickTile(
              Icons.directions_run,
              'Escapes\n19 techniques',
              Colors.amber.shade800,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SectionHeader(
          'Continue Learning',
          action: 'View All',
          actionColor: AppColors.techniques,
        ),
        SizedBox(
          height: 170,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _VideoCard(
                'Kimura from Side Control',
                '4:32',
                'Intermediate',
                0.6,
                () => _open('Kimura from Side Control'),
              ),
              _VideoCard(
                'Double Leg Takedown',
                '5:18',
                'Beginner',
                0.2,
                () => _open('Double Leg Takedown'),
              ),
              _VideoCard(
                'Triangle Choke',
                '6:02',
                'Intermediate',
                0.8,
                () => _open('Triangle Choke'),
              ),
            ],
          ),
        ),
        const SectionHeader(
          'My Favorites',
          action: 'View All',
          actionColor: AppColors.techniques,
        ),
        _Fav(
          'Armbar from Guard',
          'Submission',
          'Beginner',
          'Control the arm and isolate the elbow to finish.',
          true,
          _open,
        ),
        _Fav(
          'Kimura from Side Control',
          'Submission',
          'Intermediate',
          'Use the figure-four grip to control and submit.',
          true,
          _open,
        ),
        _Fav(
          'Single Leg Takedown',
          'Takedown',
          'Beginner',
          'A fundamental takedown for all skill levels.',
          false,
          _open,
        ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  final String title, length, level;
  final double progress;
  final VoidCallback onTap;
  const _VideoCard(
    this.title,
    this.length,
    this.level,
    this.progress,
    this.onTap,
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.play_circle,
                          color: Colors.white70,
                          size: 36,
                        ),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 4,
                        child: Text(
                          length,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  level,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const Spacer(),
                ProgressBar(progress, AppColors.techniques),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Fav extends StatelessWidget {
  final String name, category, level, blurb;
  final bool saved;
  final void Function(String) open;
  const _Fav(
    this.name,
    this.category,
    this.level,
    this.blurb,
    this.saved,
    this.open,
  );

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => open(name),
    child: Row(
      children: [
        Container(
          width: 64,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.play_circle, color: Colors.white70),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '$category  •  $level',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              Text(
                blurb,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Icon(
          saved ? Icons.bookmark : Icons.bookmark_border,
          color: saved ? AppColors.techniques : AppColors.muted,
        ),
      ],
    ),
  );
}
