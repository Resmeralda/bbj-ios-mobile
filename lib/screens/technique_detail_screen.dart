
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/technique.dart';
import '../services/practiced_service.dart';
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
  final PracticedService _practicedService = PracticedService();

  late Future<Technique?> _techniqueFuture;
  late Stream<bool> _practicedStream;

  YoutubePlayerController? _controller;
  String? _loadedVideoId;
  bool _updatingPracticed = false;

  @override
  void initState() {
    super.initState();
    _loadTechnique();
  }

  void _loadTechnique() {
    _techniqueFuture =
        TechniqueService().getTechnique(widget.techniqueId);

    _practicedStream =
        _practicedService.isPracticed(widget.techniqueId);
  }

  @override
  void didUpdateWidget(covariant TechniqueDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.techniqueId != widget.techniqueId) {
      _controller?.close();
      _controller = null;
      _loadedVideoId = null;
      _updatingPracticed = false;
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

  Future<void> _updatePracticed(bool currentStatus) async {
    if (_updatingPracticed) return;

    setState(() {
      _updatingPracticed = true;
    });

    try {
      await _practicedService.setPracticed(
        widget.techniqueId,
        !currentStatus,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentStatus
                ? 'Technique removed from practiced.'
                : 'Technique marked as practiced!',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update practiced status. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPracticed = false;
        });
      }
    }
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

              const SizedBox(height: 24),

              StreamBuilder<bool>(
                stream: _practicedStream,
                builder: (context, practicedSnapshot) {
                  if (practicedSnapshot.hasError) {
                    return const Text(
                      'Could not load practiced status.',
                    );
                  }

                  if (!practicedSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final isPracticed = practicedSnapshot.data!;

                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _updatingPracticed
                          ? null
                          : () => _updatePracticed(isPracticed),
                      icon: _updatingPracticed
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              isPracticed
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                            ),
                      label: Text(
                        isPracticed
                            ? 'Practiced - Tap to Undo'
                            : 'Mark as Practiced',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPracticed
                            ? AppColors.techniques
                            : null,
                        foregroundColor: isPracticed
                            ? Colors.white
                            : null,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
