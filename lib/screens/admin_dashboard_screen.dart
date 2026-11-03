
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _VideoSubmission {
  final String title;
  final String instructor;
  final String category;
  String status;

  _VideoSubmission({
    required this.title,
    required this.instructor,
    required this.category,
    this.status = 'Pending',
  });
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final Color adminColor = const Color(0xFF588564);

  final List<_VideoSubmission> submissions = [
    _VideoSubmission(
      title: 'Armbar from Guard',
      instructor: 'Instructor Maria',
      category: 'Submissions',
    ),
    _VideoSubmission(
      title: 'Double Leg Takedown',
      instructor: 'Instructor Nick',
      category: 'Takedowns',
    ),
    _VideoSubmission(
      title: 'Mount Escape',
      instructor: 'Instructor Alex',
      category: 'Escapes',
      status: 'Approved',
    ),
  ];

  int countStatus(String status) =>
      submissions.where((video) => video.status == status).length;

  void updateStatus(_VideoSubmission video, String status) {
    setState(() {
      video.status = status;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${video.title} marked as $status')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: adminColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Content Management',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Review and manage submitted BJJ technique videos.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),

          // Summary cards
          Row(
            children: [
              _summaryCard(
                'Pending',
                countStatus('Pending'),
                Colors.orange,
              ),
              const SizedBox(width: 8),
              _summaryCard(
                'Approved',
                countStatus('Approved'),
                Colors.green,
              ),
              const SizedBox(width: 8),
              _summaryCard(
                'Rejected',
                countStatus('Rejected'),
                Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Video Submissions',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${submissions.length} total',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Video submission cards
          for (final video in submissions) _videoCard(video),

          const SizedBox(height: 16),

          const Center(
            child: Text(
              'Demo dashboard — submissions are not saved yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoCard(_VideoSubmission video) {
    final statusColor = switch (video.status) {
      'Approved' => Colors.green,
      'Rejected' => Colors.red,
      _ => Colors.orange,
    };

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.play_circle_outline, color: adminColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    video.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${video.instructor} • ${video.category}',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                video.status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),

            if (video.status == 'Pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => updateStatus(video, 'Rejected'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: adminColor,
                      ),
                      onPressed: () => updateStatus(video, 'Approved'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
