
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/technique.dart';
import '../services/technique_service.dart';
import '../theme.dart';

class TechniqueDetailScreen extends StatefulWidget {
  final String techniqueId;

  const TechniqueDetailScreen({
    super.key,
    required this.techniqueId,
  });

  @override
  State<TechniqueDetailScreen> createState() =>
      _TechniqueDetailScreenState();
}

class _TechniqueDetailScreenState
    extends State<TechniqueDetailScreen> {
  late Future<Technique?> _techniqueFuture;

  YoutubePlayerController? _controller;
  String? _loadedVideoId;

  @override
  void initState() {
    super.initState();
    _loadTechnique();
  }

  void _loadTechnique() {
    _techniqueFuture =
        TechniqueService().getTechnique(widget.techniqueId);
  }

  @override
  void didUpdateWidget(covariant TechniqueDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.techniqueId != widget.techniqueId) {
      _controller?.close();
      _controller = null;
      _loadedVideoId = null;
      _loadTechnique();
    }
  }

  void _prepareVideo(String? videoUrl) {
    if (videoUrl == null || videoUrl.isEmpty) return;

    final videoId =
        YoutubePlayerController.convertUrlToId(videoUrl);

    if (videoId == null || videoId.isEmpty) return;

    if (_loadedVideoId == videoId) return;

    _controller?.close();

    _loadedVideoId = videoId;

    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Technique?>(
      future: _techniqueFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Could not load technique.'),
            ),
          );
        }

        final technique = snapshot.data;

        if (technique == null) {
          return const Scaffold(
            body: Center(
              child: Text('Technique not found.'),
            ),
          );
        }

        _prepareVideo(technique.videoUrl);

        return Scaffold(
          appBar: AppBar(
            title: Text(technique.name),
            backgroundColor: AppColors.techniques,
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _controller != null
                    ? YoutubePlayer(
                        controller: _controller!,
                        aspectRatio: 16 / 9,
                      )
                    : Container(
                        height: 200,
                        color: Colors.black87,
                        child: const Center(
                          child: Text(
                            'No video available',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              Chip(
                label: Text(
                  'Difficulty: ${technique.difficulty}',
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Category: ${technique.category}',
                style: const TextStyle(
                  color: AppColors.muted,
                ),
              ),

              if (technique.instructor != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Instructor: ${technique.instructor}',
                  style: const TextStyle(
                    color: AppColors.muted,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(technique.description),
            ],
          ),
        );
      },
    );
  }
}
