// Holds all mutable state for an in-progress workout session
// The active workout screen reads and writes through this object so that
// state survives navigation away from the screen and app kills
class WorkoutSession {
  final List<Map<String, dynamic>> exercises;
  final int
  startedAtMs; // DateTime.now().millisecondsSinceEpoch at session start
  String? workoutName;
  final Map<String, bool> checked; // "exIndex_setIndex" -> true
  final Map<String, String> weights; // "exIndex_setIndex_weight" -> raw string
  final Map<String, String> reps; // "exIndex_setIndex_reps" -> raw string
  int restDuration; // seconds, user-configurable
  final String? routineId;
  final String? routineName;
  final String? uid; // Firebase UID of the user who started this session

  WorkoutSession({
    required this.exercises,
    required this.startedAtMs,
    this.workoutName,
    Map<String, bool>? checked,
    Map<String, String>? weights,
    Map<String, String>? reps,
    this.restDuration = 90,
    this.routineId,
    this.routineName,
    this.uid,
  }) : checked = checked ?? {},
       weights = weights ?? {},
       reps = reps ?? {};

  Duration get elapsed => Duration(
    milliseconds: DateTime.now().millisecondsSinceEpoch - startedAtMs,
  );

  Map<String, dynamic> toJson() => {
    'exercises': exercises,
    'startedAtMs': startedAtMs,
    'workoutName': workoutName,
    'checked': checked,
    'weights': weights,
    'reps': reps,
    'restDuration': restDuration,
    'routineId': routineId,
    'routineName': routineName,
    'uid': uid,
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      exercises: (json['exercises'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      startedAtMs: json['startedAtMs'] as int,
      workoutName: json['workoutName'] as String?,
      checked: (json['checked'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, v as bool),
      ),
      weights: (json['weights'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, v as String),
      ),
      reps: (json['reps'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, v as String),
      ),
      restDuration: json['restDuration'] as int? ?? 90,
      routineId: json['routineId'] as String?,
      routineName: json['routineName'] as String?,
      uid: json['uid'] as String?,
    );
  }
}
