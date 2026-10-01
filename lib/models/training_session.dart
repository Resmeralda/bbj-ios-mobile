const sessionTypes = [
  'Gi Class',
  'No-Gi Class',
  'Open Mat',
  'Drilling / Technique',
];

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatDate(DateTime d) =>
    '${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
String formatHours(double h) => '${h.toStringAsFixed(1)} hr';

class TrainingSession {
  final String id;
  final String type;
  final DateTime date; // date and start time
  final double hours;
  final int rounds;
  final String techniques;
  final String notes;

  const TrainingSession({
    required this.id,
    required this.type,
    required this.date,
    required this.hours,
    required this.rounds,
    required this.techniques,
    required this.notes,
  });

  TrainingSession copyWith({
    String? type,
    DateTime? date,
    double? hours,
    int? rounds,
    String? techniques,
    String? notes,
  }) => TrainingSession(
    id: id,
    type: type ?? this.type,
    date: date ?? this.date,
    hours: hours ?? this.hours,
    rounds: rounds ?? this.rounds,
    techniques: techniques ?? this.techniques,
    notes: notes ?? this.notes,
  );

  // Ready for Cloud Firestore: users/{uid}/sessions/{id}
  Map<String, dynamic> toMap() => {
    'type': type,
    'date': date.toIso8601String(),
    'hours': hours,
    'rounds': rounds,
    'techniques': techniques,
    'notes': notes,
  };
}
