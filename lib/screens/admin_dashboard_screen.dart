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
  final String description;
  final String youtubeUrl;
  String status;

  _VideoSubmission({
    required this.title,
    required this.instructor,
    required this.category,
    this.description = '',
    this.youtubeUrl = '',
    this.status = 'Pending',
  });
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final Color adminColor = const Color(0xFF588564);

  String selectedFilter = 'All';

  List<_VideoSubmission> get filteredSubmissions {
    if (selectedFilter == 'All') {
      return submissions;
    }

    return submissions
        .where((video) => video.status == selectedFilter)
        .toList();
  }

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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${video.title} marked as $status')));
  }

  void _showSubmissionForm() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => _VideoSubmissionForm(
        adminColor: adminColor,
        onSubmit: (video) {
          setState(() {
            submissions.insert(0, video);
          });

          Navigator.of(sheetContext).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${video.title} submitted for review')),
          );
        },
      ),
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
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Review and manage submitted BJJ technique videos.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              _summaryCard('Pending', countStatus('Pending'), Colors.orange),
              const SizedBox(width: 8),
              _summaryCard('Approved', countStatus('Approved'), Colors.green),
              const SizedBox(width: 8),
              _summaryCard('Rejected', countStatus('Rejected'), Colors.red),
            ],
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: adminColor,
              padding: const EdgeInsets.all(16),
            ),
            onPressed: _showSubmissionForm,
            icon: const Icon(Icons.add),
            label: const Text('Submit Video'),
          ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Video Submissions',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              Text(
                '${submissions.length} total',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in ['All', 'Pending', 'Approved', 'Rejected'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: selectedFilter == filter,
                      onSelected: (_) {
                        setState(() {
                          selectedFilter = filter;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (filteredSubmissions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No submissions in this category.')),
            ),

          for (final video in filteredSubmissions) _videoCard(video),

          const SizedBox(height: 16),

          const Center(
            child: Text(
              'Demo dashboard — submissions are not saved yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
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
            Text(label, style: const TextStyle(fontSize: 12)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),

            if (video.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(video.description),
            ],

            if (video.youtubeUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                video.youtubeUrl,
                style: TextStyle(fontSize: 12, color: adminColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

            if (video.status != 'Pending') ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => updateStatus(video, 'Pending'),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reopen for Review'),
              ),
            ],

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
        ), // Column
      ), // Padding
    ); // Card
  }
}

class _VideoSubmissionForm extends StatefulWidget {
  final Color adminColor;
  final void Function(_VideoSubmission) onSubmit;

  const _VideoSubmissionForm({
    required this.adminColor,
    required this.onSubmit,
  });

  @override
  State<_VideoSubmissionForm> createState() => _VideoSubmissionFormState();
}

class _VideoSubmissionFormState extends State<_VideoSubmissionForm> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _instructorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();

  String _category = 'Submissions';

  @override
  void dispose() {
    _titleController.dispose();
    _instructorController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String? _validateYoutubeUrl(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Please enter a YouTube URL';
    }

    final uri = Uri.tryParse(text);

    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
      return 'Please enter a valid HTTPS URL';
    }

    final host = uri.host.toLowerCase();

    final youtubeHost = [
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
    ].contains(host);

    final shortHost = ['youtu.be', 'www.youtu.be'].contains(host);

    final videoId = youtubeHost && uri.path == '/watch'
        ? uri.queryParameters['v']
        : shortHost && uri.pathSegments.length == 1
        ? uri.pathSegments.first
        : youtubeHost &&
              uri.pathSegments.length == 2 &&
              ['shorts', 'embed'].contains(uri.pathSegments.first)
        ? uri.pathSegments.last
        : null;

    final validId =
        videoId != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId);

    return validId ? null : 'Enter a valid YouTube video link';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    widget.onSubmit(
      _VideoSubmission(
        title: _titleController.text.trim(),
        instructor: _instructorController.text.trim(),
        category: _category,
        description: _descriptionController.text.trim(),
        youtubeUrl: _urlController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Submit YouTube Video',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Submit a BJJ technique video for review.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Technique Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter a technique name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructorController,
                decoration: const InputDecoration(
                  labelText: 'Instructor Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter an instructor name'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Submissions',
                    child: Text('Submissions'),
                  ),
                  DropdownMenuItem(
                    value: 'Takedowns',
                    child: Text('Takedowns'),
                  ),
                  DropdownMenuItem(value: 'Guard', child: Text('Guard')),
                  DropdownMenuItem(value: 'Escapes', child: Text('Escapes')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'YouTube Video URL',
                  hintText: 'https://www.youtube.com/watch?v=...',
                  border: OutlineInputBorder(),
                ),
                validator: _validateYoutubeUrl,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: widget.adminColor,
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: _submit,
                icon: const Icon(Icons.send),
                label: const Text('Submit Video'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
