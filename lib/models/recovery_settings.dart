class RecoverySettings {
  const RecoverySettings({this.sleepGoalHours = 8, this.showHrv = true});

  final double sleepGoalHours;
  final bool showHrv;

  static bool isValidSleepGoal(double? hours) =>
      hours != null && hours.isFinite && hours >= 1 && hours <= 24;

  String get sleepGoalLabel {
    final hours = sleepGoalHours.toString();
    return '${hours.endsWith('.0') ? hours.substring(0, hours.length - 2) : hours} hr';
  }

  factory RecoverySettings.fromMap(Map<String, dynamic>? data) {
    final hours = data?['sleepGoalHours'];
    final hrv = data?['showHrv'];
    return RecoverySettings(
      sleepGoalHours: hours is num && isValidSleepGoal(hours.toDouble())
          ? hours.toDouble()
          : const RecoverySettings().sleepGoalHours,
      showHrv: hrv is bool ? hrv : true,
    );
  }

  Map<String, dynamic> toMap() => {
    'sleepGoalHours': sleepGoalHours,
    'showHrv': showHrv,
  };
}
