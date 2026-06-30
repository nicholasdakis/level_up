import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utility/shared_preferences/shared_prefs_async.dart';

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
    );
  }
}

// Global singleton, access via workoutSessionService in globals.dart
class WorkoutSessionService extends ChangeNotifier {
  WorkoutSession? _session;
  WorkoutSession? get session => _session;
  bool get isActive => _session != null;

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  // Start a new session, replaces any existing session
  void startSession(WorkoutSession session) {
    _session = session;
    notifyListeners();
    _persist();
  }

  // Called by the active workout screen on every mutation that should survive a kill
  void persist() {
    _persist();
  }

  // Notify listeners without changing state, used to trigger UI rebuilds (e.g. timer tick).
  void tick() {
    notifyListeners();
  }

  // Clear session on finish or discard
  void clearSession() {
    _session = null;
    notifyListeners();
    _prefs.remove(SharedPreferencesKey.activeWorkoutSession);
  }

  // Called on app launch, returns true if a session was restored
  Future<bool> tryRestore() async {
    try {
      final raw = await _prefs.getString(
        SharedPreferencesKey.activeWorkoutSession,
      );
      if (raw == null) return false;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _session = WorkoutSession.fromJson(json);
      notifyListeners();
      return true;
    } catch (_) {
      // Corrupted data, clear it
      await _prefs.remove(SharedPreferencesKey.activeWorkoutSession);
      return false;
    }
  }

  void _persist() {
    if (_session == null) return;
    final json = jsonEncode(_session!.toJson());
    _prefs.setString(SharedPreferencesKey.activeWorkoutSession, json);
  }
}
