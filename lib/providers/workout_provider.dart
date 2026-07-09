import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_session.dart';
import 'package:flutter/foundation.dart';
import '../globals.dart' show isGuest;
import '../services/user_data_manager.dart'
    show authenticatedGet, authenticatedPost;
import 'user_data_provider.dart' show userDataProvider;
import '../utility/shared_preferences/shared_prefs_async.dart';

// All workout-related state in one place so screens only need to watch this provider
class WorkoutState {
  // null means no workout is currently in progress
  final WorkoutSession? activeSession;
  // true while loadWorkoutData is in flight, drives the skeletonizer
  final bool isLoading;
  // fetched from the backend, displayed on the workout tab
  final List<Map<String, dynamic>> recentWorkouts;
  final List<Map<String, dynamic>> myRoutines;
  final int weeklyWorkoutCount;
  // date string to count map used to render the activity heatmap
  final Map<String, int> heatmap;
  // summary of today's completed workout (volume, muscles, etc.)
  final Map<String, dynamic> todayOverview;
  // featured + community routines for the browse screen
  final Map<String, dynamic> browseRoutines;
  // recent exercises for the exercise picker
  final List<Map<String, dynamic>> recentExercises;

  const WorkoutState({
    this.activeSession,
    this.isLoading = false,
    this.recentWorkouts = const [],
    this.myRoutines = const [],
    this.weeklyWorkoutCount = 0,
    this.heatmap = const {},
    this.todayOverview = const {},
    this.browseRoutines = const {'featured': [], 'community': []},
    this.recentExercises = const [],
  });

  // clearSession: true sets activeSession to null even if no new value is passed
  WorkoutState copyWith({
    WorkoutSession? activeSession,
    bool clearSession = false,
    bool? isLoading,
    List<Map<String, dynamic>>? recentWorkouts,
    List<Map<String, dynamic>>? myRoutines,
    int? weeklyWorkoutCount,
    Map<String, int>? heatmap,
    Map<String, dynamic>? todayOverview,
    Map<String, dynamic>? browseRoutines,
    List<Map<String, dynamic>>? recentExercises,
  }) {
    return WorkoutState(
      activeSession: clearSession ? null : activeSession ?? this.activeSession,
      isLoading: isLoading ?? this.isLoading,
      recentWorkouts: recentWorkouts ?? this.recentWorkouts,
      myRoutines: myRoutines ?? this.myRoutines,
      weeklyWorkoutCount: weeklyWorkoutCount ?? this.weeklyWorkoutCount,
      heatmap: heatmap ?? this.heatmap,
      todayOverview: todayOverview ?? this.todayOverview,
      browseRoutines: browseRoutines ?? this.browseRoutines,
      recentExercises: recentExercises ?? this.recentExercises,
    );
  }
}

class WorkoutNotifier extends AsyncNotifier<WorkoutState> {
  // fires every second while a session is active to drive the elapsed time display
  Timer? _ticker;

  @override
  // start with empty state, session is restored separately via checkAndRestoreWorkoutSession
  Future<WorkoutState> build() async => const WorkoutState();

  // starts the 1-second ticker that causes elapsed time watchers to rebuild
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = state.value;
      if (current?.activeSession != null) {
        // reassigning the same object triggers a rebuild in widgets using .select on elapsed
        state = AsyncData(current!);
      } else {
        _ticker?.cancel();
      }
    });
  }

  // stamps the current user's UID onto the session so restore can reject foreign sessions
  void startSession(WorkoutSession session) {
    final uid = ref.read(userDataProvider).value?.uid;
    final stamped = WorkoutSession(
      exercises: session.exercises,
      startedAtMs: session.startedAtMs,
      workoutName: session.workoutName,
      checked: session.checked,
      weights: session.weights,
      reps: session.reps,
      restDuration: session.restDuration,
      routineId: session.routineId,
      routineName: session.routineName,
      uid: uid,
    );
    _persistSession(stamped);
    // delay so the mini bar does not flash during the active workout screen slide-up transition
    // and to avoid modifying provider state during widget mount (Riverpod forbids this)
    Future.delayed(const Duration(milliseconds: 500), () {
      state = AsyncData(
        (state.value ?? const WorkoutState()).copyWith(activeSession: stamped),
      );
      _startTicker();
    });
  }

  // called by ActiveWorkoutScreen after every mutation (set checked, weight changed, etc.)
  void persist() {
    final session = state.value?.activeSession;
    if (session == null) return;
    _persistSession(session);
    // reassign state so watchers know something changed without replacing the session object
    state = AsyncData(state.value ?? const WorkoutState());
  }

  // called when the user finishes or discards a workout
  void clearSession() {
    _ticker?.cancel();
    SharedPreferencesAsync().remove(SharedPreferencesKey.activeWorkoutSession);
    state = AsyncData(
      (state.value ?? const WorkoutState()).copyWith(clearSession: true),
    );
  }

  // called on app launch to restore a session that survived a kill or navigation away
  Future<void> checkAndRestoreWorkoutSession() async {
    if (isGuest) return;
    try {
      final raw = await SharedPreferencesAsync().getString(
        SharedPreferencesKey.activeWorkoutSession,
      );
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final restored = WorkoutSession.fromJson(json);
      // reject sessions that belong to a different logged-in account
      final currentUid = ref.read(userDataProvider).value?.uid;
      if (restored.uid != null && restored.uid != currentUid) {
        await SharedPreferencesAsync().remove(
          SharedPreferencesKey.activeWorkoutSession,
        );
        return;
      }
      final current = state.value ?? const WorkoutState();
      state = AsyncData(current.copyWith(activeSession: restored));
      _startTicker();
    } catch (e) {
      debugPrint('checkAndRestoreWorkoutSession error: $e');
      await SharedPreferencesAsync().remove(
        SharedPreferencesKey.activeWorkoutSession,
      );
    }
  }

  // fetches all workout tab data in parallel and patches state once done
  Future<void> loadWorkoutData() async {
    if (isGuest) return;
    state = AsyncData(
      (state.value ?? const WorkoutState()).copyWith(isLoading: true),
    );
    try {
      final results = await Future.wait([
        authenticatedGet(
          'recent_workouts',
          timeout: const Duration(seconds: 8),
        ),
        authenticatedGet('my_routines', timeout: const Duration(seconds: 8)),
        authenticatedGet(
          'weekly_workout_count',
          timeout: const Duration(seconds: 8),
        ),
        authenticatedGet(
          'workout_heatmap',
          timeout: const Duration(seconds: 8),
        ),
        authenticatedGet('today_overview', timeout: const Duration(seconds: 8)),
      ]);

      final recentWorkouts = results[0].statusCode == 200
          ? (jsonDecode(results[0].body)['workouts'] as List)
                .map((w) => Map<String, dynamic>.from(w as Map))
                .toList()
          : (state.value ?? const WorkoutState()).recentWorkouts;

      final myRoutines = results[1].statusCode == 200
          ? (jsonDecode(results[1].body)['routines'] as List)
                .map((r) => Map<String, dynamic>.from(r as Map))
                .toList()
          : (state.value ?? const WorkoutState()).myRoutines;

      final weeklyWorkoutCount = results[2].statusCode == 200
          ? (jsonDecode(results[2].body)['count'] as int? ?? 0)
          : (state.value ?? const WorkoutState()).weeklyWorkoutCount;

      final heatmap = results[3].statusCode == 200
          ? {
              for (final d in jsonDecode(results[3].body)['days'] as List)
                d['date'] as String: d['count'] as int,
            }
          : (state.value ?? const WorkoutState()).heatmap;

      final todayOverview = results[4].statusCode == 200
          ? Map<String, dynamic>.from(jsonDecode(results[4].body) as Map)
          : (state.value ?? const WorkoutState()).todayOverview;

      state = AsyncData(
        (state.value ?? const WorkoutState()).copyWith(
          isLoading: false,
          recentWorkouts: recentWorkouts,
          myRoutines: myRoutines,
          weeklyWorkoutCount: weeklyWorkoutCount,
          heatmap: heatmap,
          todayOverview: todayOverview,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('loadWorkoutData failed: $e');
      state = AsyncData(
        (state.value ?? const WorkoutState()).copyWith(isLoading: false),
      );
    }
  }

  Future<bool> createRoutine({
    required String name,
    required List<Map<String, dynamic>> exercises,
    int? estimatedDurationMinutes,
  }) async {
    try {
      final response = await authenticatedPost(
        'create_routine',
        body: {
          'name': name,
          'exercises': exercises,
          'estimated_duration_minutes': ?estimatedDurationMinutes,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('createRoutine failed: $e');
    }
    return false;
  }

  // copies a public browse routine into the user's own routines and appends it to myRoutines
  Future<bool> copyRoutine(
    String templateId, {
    Map<String, dynamic>? routineData,
  }) async {
    try {
      final response = await authenticatedPost(
        'copy_routine',
        body: {'template_id': templateId},
      );
      if (response.statusCode == 200) {
        if (routineData != null) {
          final previous = state.value ?? const WorkoutState();
          state = AsyncData(
            previous.copyWith(
              myRoutines: [...previous.myRoutines, routineData],
            ),
          );
        }
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('copyRoutine failed: $e');
    }
    return false;
  }

  Future<bool> likeRoutine(String templateId) async {
    try {
      final response = await authenticatedPost(
        'like_routine',
        body: {'template_id': templateId},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('likeRoutine failed: $e');
    }
    return false;
  }

  Future<bool> unlikeRoutine(String templateId) async {
    try {
      final response = await authenticatedPost(
        'unlike_routine',
        body: {'template_id': templateId},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('unlikeRoutine failed: $e');
    }
    return false;
  }

  Future<bool> deleteCustomExercise(int exerciseId) async {
    try {
      final response = await authenticatedPost(
        'delete_custom_exercise',
        body: {'exercise_id': exerciseId},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('deleteCustomExercise failed: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>?> createCustomExercise({
    required String name,
    String? primaryMuscle,
    List<String> secondaryMuscles = const [],
    String? equipment,
    String? level,
  }) async {
    try {
      final response = await authenticatedPost(
        'create_custom_exercise',
        body: {
          'name': name,
          'primary_muscle': primaryMuscle,
          'secondary_muscles': secondaryMuscles,
          'equipment': equipment,
          'level': level,
        },
      );
      final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (response.statusCode == 200) return data;
      return {'error': data['error'] ?? 'Failed to create exercise'};
    } catch (e) {
      if (kDebugMode) debugPrint('createCustomExercise failed: $e');
    }
    return null;
  }

  Future<bool> editCustomExercise({
    required int exerciseId,
    required String name,
    String? primaryMuscle,
    List<String> secondaryMuscles = const [],
    String? equipment,
    String? level,
  }) async {
    try {
      final response = await authenticatedPost(
        'edit_custom_exercise',
        body: {
          'exercise_id': exerciseId,
          'name': name,
          'primary_muscle': primaryMuscle,
          'secondary_muscles': secondaryMuscles,
          'equipment': equipment,
          'level': level,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('editCustomExercise failed: $e');
    }
    return false;
  }

  // returns previous sets keyed by exercise_name -> set_number -> {weight_kg, reps}
  Future<Map<String, Map<int, Map<String, dynamic>>>> fetchEveryPrevSet(
    List<String> exerciseNames,
  ) async {
    try {
      final response = await authenticatedPost(
        'every_prev_set',
        body: {'exercise_names': exerciseNames},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = <String, Map<int, Map<String, dynamic>>>{};
        for (final prevSet in data['sets'] as List) {
          final setMap = Map<String, dynamic>.from(prevSet as Map);
          final exerciseName = setMap['exercise_name'] as String;
          final setNumber = setMap['set_number'] as int;
          result.putIfAbsent(exerciseName, () => {});
          result[exerciseName]![setNumber] = setMap;
        }
        return result;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchEveryPrevSet failed: $e');
    }
    return {};
  }

  Future<Map<String, Map<String, dynamic>>> fetchExerciseStats() async {
    try {
      final response = await authenticatedGet('exercise_stats');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final stats = (data['stats'] as List)
            .map((stat) => Map<String, dynamic>.from(stat as Map))
            .toList();
        return {
          for (final stat in stats) stat['exercise_name'] as String: stat,
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchExerciseStats failed: $e');
    }
    return {};
  }

  // optimistically removes a routine, rolls back on failure
  Future<bool> deleteRoutine(String templateId) async {
    final previous = state.value ?? const WorkoutState();
    state = AsyncData(
      previous.copyWith(
        myRoutines: previous.myRoutines
            .where((r) => r['template_id'] != templateId)
            .toList(),
      ),
    );
    try {
      final response = await authenticatedPost(
        'delete_routine',
        body: {'template_id': templateId},
      );
      if (response.statusCode == 200) return true;
      state = AsyncData(previous);
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('deleteRoutine failed: $e');
      state = AsyncData(previous);
      return false;
    }
  }

  // loads browse routines for the browse screen
  Future<void> loadBrowseRoutines() async {
    if (isGuest) return;
    try {
      final response = await authenticatedGet(
        'browse_routines',
        timeout: const Duration(seconds: 10),
      );
      if (response.statusCode == 200) {
        state = AsyncData(
          (state.value ?? const WorkoutState()).copyWith(
            browseRoutines: Map<String, dynamic>.from(
              jsonDecode(response.body) as Map,
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('loadBrowseRoutines failed: $e');
    }
  }

  // loads recent exercises for the exercise picker
  Future<void> loadRecentExercises() async {
    if (isGuest) return;
    try {
      final response = await authenticatedGet(
        'recent_exercises',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        state = AsyncData(
          (state.value ?? const WorkoutState()).copyWith(
            recentExercises: (data['exercises'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('loadRecentExercises failed: $e');
    }
  }

  // refreshes only the data that changes after a workout is saved
  Future<void> refreshAfterWorkout() async {
    if (isGuest) return;
    try {
      final results = await Future.wait([
        authenticatedGet(
          'recent_workouts',
          timeout: const Duration(seconds: 8),
        ),
        authenticatedGet(
          'weekly_workout_count',
          timeout: const Duration(seconds: 8),
        ),
        authenticatedGet('today_overview', timeout: const Duration(seconds: 8)),
      ]);

      final recentWorkouts = results[0].statusCode == 200
          ? (jsonDecode(results[0].body)['workouts'] as List)
                .map((w) => Map<String, dynamic>.from(w as Map))
                .toList()
          : (state.value ?? const WorkoutState()).recentWorkouts;

      final weeklyWorkoutCount = results[1].statusCode == 200
          ? (jsonDecode(results[1].body)['count'] as int? ?? 0)
          : (state.value ?? const WorkoutState()).weeklyWorkoutCount;

      final todayOverview = results[2].statusCode == 200
          ? Map<String, dynamic>.from(jsonDecode(results[2].body) as Map)
          : (state.value ?? const WorkoutState()).todayOverview;

      state = AsyncData(
        (state.value ?? const WorkoutState()).copyWith(
          recentWorkouts: recentWorkouts,
          weeklyWorkoutCount: weeklyWorkoutCount,
          todayOverview: todayOverview,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('refreshAfterWorkout failed: $e');
    }
  }

  // fire-and-forget write to SharedPrefs, no need to await
  void _persistSession(WorkoutSession session) {
    SharedPreferencesAsync().setString(
      SharedPreferencesKey.activeWorkoutSession,
      jsonEncode(session.toJson()),
    );
  }
}

final workoutProvider = AsyncNotifierProvider<WorkoutNotifier, WorkoutState>(
  WorkoutNotifier.new,
);
