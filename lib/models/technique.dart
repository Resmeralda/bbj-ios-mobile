class Technique {
  static const categories = ['Takedowns', 'Submissions', 'Guard', 'Escapes'];
  static const difficulties = ['Beginner', 'Intermediate', 'Advanced'];

  static final _youtube = RegExp(
    r'^https?://((www[.]|m[.])?youtube[.]com/(watch[?]([^# ]*&)?v=|(embed|shorts|live)/)|youtu[.]be/)([A-Za-z0-9_-]{11})([?&#][^\s]*)?$',
  );

  static String? youtubeId(String? url) {
    if (url == null) return null;
    return _youtube.firstMatch(url.trim())?.group(6);
  }

  final String id;
  final String name;
  final String category;
  final String difficulty;
  final String description;
  final String? videoUrl;
  final String? instructor;
  final String? videoSource;

  const Technique({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.description,
    this.videoUrl,
    this.instructor,
    this.videoSource,
  });

  Map<String, String> toPublication() => {
    'name': name,
    'category': category,
    'description': description,
    'difficulty': difficulty,
    'instructor': instructor ?? '',
    'videoUrl': videoUrl ?? '',
  };

  factory Technique.fromMap(String id, Map<String, dynamic> data) {
    return Technique(
      id: id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      difficulty: data['difficulty'] as String? ?? '',
      description: data['description'] as String? ?? '',
      videoUrl: data['videoUrl'] as String?,
      instructor: data['instructor'] as String?,
      videoSource: data['videoSource'] as String?,
    );
  }
}
