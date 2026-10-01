import 'package:flutter/material.dart';

import '../theme.dart';

class TechniqueDetailScreen extends StatelessWidget {
  final String name;
  const TechniqueDetailScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(Uri.decodeComponent(name)),
      backgroundColor: AppColors.techniques,
      foregroundColor: Colors.white,
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Icon(Icons.play_circle, color: Colors.white70, size: 64),
          ),
        ), // TODO: video_player / youtube player
        const SizedBox(height: 16),
        const Chip(label: Text('Difficulty: Beginner')),
        const SizedBox(height: 8),
        const Text(
          'Description',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Technique description loaded from Cloud Firestore goes here.',
        ),
      ],
    ),
  );
}
