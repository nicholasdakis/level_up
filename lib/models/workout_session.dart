import 'dart:math';

// Holds all mutable state for an in-progress workout session
// The active workout screen reads and writes through this object so that
// state survives navigation away from the screen and app kills
class WorkoutSession {
  final List<Map<String, dynamic>> exercises;
  int startedAtMs; // DateTime.now().millisecondsSinceEpoch at session start
  String? workoutName;
  final String
  sessionId; // generated once at session start, sent with log_workout for idempotency
  final Map<String, bool> checked; // "exIndex_setIndex" -> true
  final Map<String, String> weights; // "exIndex_setIndex_weight" -> raw string
  final Map<String, String> reps; // "exIndex_setIndex_reps" -> raw string
  int restDuration; // seconds, user-configurable
  bool restEnabled; // whether the rest timer auto-starts after a set
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
    this.restEnabled = true,
    this.routineId,
    this.routineName,
    this.uid,
    String? sessionId,
  }) : checked = checked ?? {},
       weights = weights ?? {},
       reps = reps ?? {},
       sessionId = sessionId ?? generateId();

  static String generateId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    // format as xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx (UUID v4)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

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
    'restEnabled': restEnabled,
    'routineId': routineId,
    'routineName': routineName,
    'uid': uid,
    'sessionId': sessionId,
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final exercises = (json['exercises'] as List).map((e) {
      final ex = Map<String, dynamic>.from(e as Map);
      ex['sets'] = (ex['sets'] as List).map((s) {
        final set = Map<String, dynamic>.from(s as Map);
        set['uuid'] ??= generateId();
        return set;
      }).toList();
      return ex;
    }).toList();
    return WorkoutSession(
      exercises: exercises,
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
      restEnabled: json['restEnabled'] as bool? ?? true,
      routineId: json['routineId'] as String?,
      routineName: json['routineName'] as String?,
      uid: json['uid'] as String?,
      sessionId: json['sessionId'] as String?,
    );
  }
}
