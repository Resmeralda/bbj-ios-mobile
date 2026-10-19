
class Technique {
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

  factory Technique.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
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
