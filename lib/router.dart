import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'screens/update_required.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'services/user_data_manager.dart' show backendBaseUrl;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'home_screen.dart';
import 'authentication/register_or_login.dart';
import 'screens/app_shell.dart';
import 'screens/calorie_calculator.dart';
import 'screens/calorie_calculator/results.dart';
import 'screens/food_logging.dart';
import 'screens/analytics/food_analytics.dart';
import 'screens/analytics/weight_analytics.dart';
import 'screens/analytics/water_analytics.dart';
import 'screens/reminders.dart';
import 'screens/badges.dart';
import 'screens/leaderboard.dart';
import 'screens/progression.dart';
import 'screens/explore.dart';
import 'screens/settings/personal_preferences.dart';
import 'screens/settings/about_the_developer.dart';
import 'screens/settings/install_guide.dart';
import 'screens/settings/changelog.dart';
import 'globals.dart';
import 'services/fcm/fcm_service.dart';
import 'screens/log_food_screen.dart';
import 'utility/web_utils_stub.dart'
    if (dart.library.js_interop) 'utility/web_utils_web.dart'
    as web_fcm;

// Notifies go_router to re-run the redirect check when Firebase auth state changes
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
    guestNotifier.addListener(notifyListeners);
  }
}

final _authNotifier = _AuthNotifier();

// Root navigator key, used so sub-routes can push over the shell
final _rootNavKey = GlobalKey<NavigatorState>(debugLabel: 'root');

// Navigator keys, one per shell branch
final _homeNavKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _foodNavKey = GlobalKey<NavigatorState>(debugLabel: 'food');
// final _workoutNavKey = GlobalKey<NavigatorState>(debugLabel: 'workout');
final _exploreNavKey = GlobalKey<NavigatorState>(debugLabel: 'explore');
final _leaderboardNavKey = GlobalKey<NavigatorState>(debugLabel: 'leaderboard');

// slides in from the right on push, instant on pop
Page _slidePage({required LocalKey key, required Widget child}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOut)).animate(animation),
        child: child,
      );
    },
  );
}

// slides up from the bottom, feels like an extension of the parent screen rather than a new screen
Page _slideUpPage({required LocalKey key, required Widget child}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
        child: child,
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavKey,
  initialLocation: '/loading',
  debugLogDiagnostics: kDebugMode,
  routerNeglect: false,
  // re-evaluates redirect when auth state changes
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    // if a real Firebase user signed in while in guest mode, clear guest state so init runs fresh
    if (isGuest && FirebaseAuth.instance.currentUser != null) {
      isGuest = false;
      userDataNotifier.value = null;
      appInitialized = false;
      appReadyNotifier.value = false;
      guestNotifier.value = false;
    }
    final isLoggedIn = FirebaseAuth.instance.currentUser != null || isGuest;
    final onLogin = state.matchedLocation == '/login';
    final onLoading = state.matchedLocation == '/loading';
    if (suppressAuthRedirect) {
      return null; // TOS check in progress
    }
    // force outdated users to the update screen
    if (isAppOutdated && state.matchedLocation != '/update-required') {
      return '/update-required';
    }

    // send logged-out users to login
    if (!isLoggedIn && !onLogin) return '/login';

    // send already-logged-in users away from login
    if (isLoggedIn && onLogin) return '/loading';

    // if init hasn't run yet (e.g. user refreshed on a sub-route), run it first
    if (isLoggedIn && !onLoading && !appInitialized) return '/loading';

    // init is done and user is still on loading
    // restores sub-route on web page refresh (e.g. /food-logging), falls back to /
    if (isLoggedIn && onLoading && appInitialized) {
      if (isGuest) return '/';
      final path = appLaunchUri.path.replaceFirst('/level_up', '');
      final query = appLaunchUri.query.isNotEmpty
          ? '?${appLaunchUri.query}'
          : '';
      return (path.isNotEmpty && path != '/loading' && path != '/login')
          ? '$path$query'
          : '/';
    }

    return null; // no redirect needed
  },
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) =>
          NoTransitionPage(key: state.pageKey, child: const RegisterOrLogin()),
    ),
    GoRoute(
      path: '/loading',
      pageBuilder: (context, state) =>
          NoTransitionPage(key: state.pageKey, child: const AppInitScreen()),
    ),

    // Shell wrapping the 5 persistent tabs
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        // Home tab
        StatefulShellBranch(
          navigatorKey: _homeNavKey,
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const HomeScreen(),
              ),
            ),
          ],
        ),

        // Food Logging tab
        StatefulShellBranch(
          navigatorKey: _foodNavKey,
          routes: [
            GoRoute(
              path: '/food-logging',
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const FoodLogging(),
              ),
              routes: [
                GoRoute(
                  path: 'analytics',
                  parentNavigatorKey: _rootNavKey,
                  redirect: (context, state) =>
                      state.extra == null ? '/food-logging' : null,
                  pageBuilder: (context, state) {
                    final p = state.extra as Map<String, dynamic>;
                    final noAnim = p['noAnimation'] == true;
                    return noAnim
                        ? NoTransitionPage(
                            key: state.pageKey,
                            child: FoodAnalyticsScreen(
                              initialDate: p['initialDate'] as DateTime,
                              onDateChanged:
                                  p['onDateChanged']
                                      as void Function(DateTime)?,
                            ),
                          )
                        : _slideUpPage(
                            key: state.pageKey,
                            child: FoodAnalyticsScreen(
                              initialDate: p['initialDate'] as DateTime,
                              onDateChanged:
                                  p['onDateChanged']
                                      as void Function(DateTime)?,
                            ),
                          );
                  },
                ),
                GoRoute(
                  path: 'log',
                  parentNavigatorKey: _rootNavKey,
                  redirect: (context, state) =>
                      state.extra == null ? '/food-logging' : null,
                  pageBuilder: (context, state) {
                    final p = state.extra as Map<String, dynamic>;
                    return _slideUpPage(
                      key: state.pageKey,
                      child: LogFoodScreen(
                        meal: p['meal'] as String,
                        currentDate: p['currentDate'] as DateTime,
                        onFoodLogged: p['onFoodLogged'] as VoidCallback,
                        achievementId: p['achievementId'] as String?,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // Workout tab commented out until workouts are implemented
        // StatefulShellBranch(
        //   navigatorKey: _workoutNavKey,
        //   routes: [
        //     GoRoute(
        //       path: '/workout',
        //       pageBuilder: (context, state) => NoTransitionPage(
        //         key: state.pageKey,
        //         child: const Scaffold(
        //           backgroundColor: Color(0xFF0A0F1E),
        //           body: Center(
        //             child: Text(
        //               'Coming Soon',
        //               style: TextStyle(color: Colors.white54, fontSize: 16),
        //             ),
        //           ),
        //         ),
        //       ),
        //     ),
        //   ],
        // ),

        // Progression tab
        StatefulShellBranch(
          navigatorKey: _leaderboardNavKey,
          routes: [
            GoRoute(
              path: '/progression',
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const Progression(),
              ),
            ),
          ],
        ),

        // Explore tab
        StatefulShellBranch(
          navigatorKey: _exploreNavKey,
          routes: [
            GoRoute(
              path: '/explore',
              pageBuilder: (context, state) =>
                  NoTransitionPage(key: state.pageKey, child: const Explore()),
            ),
          ],
        ),
      ],
    ),

    // Push routes over the shell (no nav bar visible on these)
    GoRoute(
      path: '/badges',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const Badges()),
    ),
    GoRoute(
      path: '/leaderboard',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const Leaderboard()),
    ),
    GoRoute(
      path: '/reminders',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const Reminders()),
    ),
    GoRoute(
      path: '/calorie-calculator',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const CalorieCalculator()),
      routes: [
        GoRoute(
          path: 'results',
          redirect: (context, state) =>
              state.extra == null ? '/calorie-calculator' : null,
          pageBuilder: (context, state) {
            final p = state.extra as Map<String, dynamic>;
            return _slidePage(
              key: state.pageKey,
              child: Results(
                units: p['units'] as String?,
                goal: p['goal'] as String?,
                sex: p['sex'] as String?,
                activityLevel: p['activityLevel'] as String?,
                equation: p['equation'] as String?,
                age: p['age'] as int?,
                heightCm: p['heightCm'] as int?,
                heightInches: p['heightInches'] as int?,
                weight: p['weight'] as double?,
              ),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/settings/preferences',
      pageBuilder: (context, state) => _slidePage(
        key: state.pageKey,
        child: PersonalPreferences(
          onProfileImageUpdated: state.extra as VoidCallback?,
        ),
      ),
    ),
    GoRoute(
      path: '/settings/developer',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const AboutTheDeveloper()),
    ),
    GoRoute(
      path: '/settings/install',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const InstallGuide()),
    ),
    GoRoute(
      path: '/settings/changelog',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const ChangelogScreen()),
    ),
    GoRoute(
      path: '/weight/analytics',
      pageBuilder: (context, state) => _slideUpPage(
        key: state.pageKey,
        child: const WeightAnalyticsScreen(),
      ),
    ),
    GoRoute(
      path: '/water/analytics',
      pageBuilder: (context, state) =>
          _slideUpPage(key: state.pageKey, child: const WaterAnalyticsScreen()),
    ),
    GoRoute(
      path: '/update-required',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const UpdateRequiredScreen(),
      ),
    ),
  ],
);

// Runs app init once and redirects to / when done.
// Uses NoTransitionPage so there is no animation into or out of the loading screen.
class AppInitScreen extends StatefulWidget {
  const AppInitScreen({super.key});

  @override
  State<AppInitScreen> createState() => _AppInitScreenState();
}

class _AppInitScreenState extends State<AppInitScreen> {
  late final VoidCallback _colorListener;

  @override
  void initState() {
    super.initState();
    // rebuild spinner when theme color changes while loading
    _colorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_colorListener);
    _initApp();
  }

  @override
  void dispose() {
    appColorNotifier.removeListener(_colorListener);
    super.dispose();
  }

  // returns true if the installed version is below the minimum required
  // returns false if the backend is unreachable so users are never blocked by a network failure
  Future<bool> _isOutdated() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final response = await http
          .get(Uri.parse('$backendBaseUrl/app_config'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;
      final minVersion =
          (jsonDecode(response.body) as Map)['min_version'] as String?;
      if (minVersion == null) return false;
      // split "1.2.3" into [1, 2, 3] for numeric part-by-part comparison
      List<int> parts(String v) => v.split('.').map(int.parse).toList();
      // strip build metadata (e.g. "1.1.4+35" -> "1.1.4") before comparing
      final cur = parts(info.version.split('+').first);
      final req = parts(minVersion);
      // compare major, minor, patch in order
      for (int i = 0; i < req.length; i++) {
        final c = i < cur.length ? cur[i] : 0;
        if (c < req[i]) return true; // outdated
        if (c > req[i]) return false; // newer, fine
      }
      return false; // equal
    } catch (_) {
      return false; // let the user through if anything fails
    }
  }

  Future<void> _initApp() async {
    // Navigate immediately so the skeletonizer shows instead of a blank loading screen
    appInitialized = true;
    Future.microtask(appRouter.refresh);

    if (await _isOutdated()) {
      isAppOutdated = true;
      appRouter.refresh();
      return;
    }

    await userManager.loadUserData();

    userManager.updateUtcOffset();
    expNotifier.value = currentUserData?.expPoints ?? 0;

    if (currentUserData != null) {
      appColorNotifier.value = currentUserData!.appColor;
      try {
        // Update the body background so the notch / loading screen matches the app color
        String toHex(Color c) {
          final a = c.toARGB32();
          return '#'
              '${((a >> 16) & 0xFF).toRadixString(16).padLeft(2, '0')}'
              '${((a >> 8) & 0xFF).toRadixString(16).padLeft(2, '0')}'
              '${(a & 0xFF).toRadixString(16).padLeft(2, '0')}';
        }

        final base = currentUserData!.appColor;
        final dark = darkenColor(base, 0.015);
        final mid = lightenColor(base, 0.015);
        final notch = darkenColor(base, 0.07);
        web_fcm.setAppColor('${toHex(dark)}|${toHex(mid)}|${toHex(notch)}');
      } catch (e) {
        if (kDebugMode) debugPrint('setAppColor failed: $e');
      }
    }

    if (mounted && !isGuest) FcmService.initialize(context);

    appReadyNotifier.value = true;
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
