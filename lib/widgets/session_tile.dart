import 'package:flutter/material.dart';

import '../models/training_session.dart';
import '../theme.dart';
import 'common.dart';

Color sessionColor(String type) => switch (type) {
  'Gi Class' => AppColors.home,
  'No-Gi Class' => Colors.deepPurple,
  'Open Mat' => Colors.deepOrange,
  _ => Colors.amber.shade800,
};

class SessionTile extends StatelessWidget {
  final TrainingSession session;
  final VoidCallback? onTap;
  const SessionTile(this.session, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = sessionColor(session.type);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.sports_martial_arts, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(session.date),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                Text(
                  session.type,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${formatHours(session.hours)}   •   ${session.rounds} rounds',
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (session.techniques.isNotEmpty)
                  Text(
                    session.techniques,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
