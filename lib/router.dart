import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'home_screen.dart';
import 'authentication/register_or_login.dart';
import 'screens/calorie_calculator.dart';
import 'screens/calorie_calculator/results.dart';
import 'screens/food_logging.dart';
import 'screens/food_logging_charts.dart';
import 'screens/reminders.dart';
import 'screens/badges.dart';
import 'screens/leaderboard.dart';
import 'screens/explore.dart';
import 'screens/settings/personal_preferences.dart';
import 'screens/settings/about_the_developer.dart';
import 'screens/settings/install_guide.dart';
import 'globals.dart';
import 'services/fcm/fcm_service.dart';
import 'package:flutter/foundation.dart';
import 'utility/responsive.dart';

// Notifies go_router to re-run the redirect check when Firebase auth state changes
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      debugPrint('auth state changed');
      notifyListeners();
    });
  }
}

final _authNotifier = _AuthNotifier();

// Set to true by AppInitScreen once _initApp completes
bool _appInitialized = false;

// CupertinoPageRoute subclass that skips the reverse transition when the iOS
// swipe-back gesture is driving the animation, preventing the double-transition bug
class _SlideRoute<T> extends CupertinoPageRoute<T> {
  _SlideRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // swipe gesture is in progress or just completed so skip the animation
    if (popGestureInProgress) return child;

    return SlideTransition(
      position: Tween(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOut)).animate(animation),
      child: child,
    );
  }
}

// Page subclass that creates _SlideRoute so go_router uses our custom transition
class _SlidePage<T> extends Page<T> {
  final Widget child;
  const _SlidePage({required super.key, required this.child});

  @override
  Route<T> createRoute(BuildContext context) {
    return _SlideRoute<T>(settings: this, builder: (_) => child);
  }
}

Page _slidePage({required LocalKey key, required Widget child}) {
  if (kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    return NoTransitionPage(key: key, child: child);
  }
  return _SlidePage(key: key, child: child);
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/loading',
  debugLogDiagnostics: true,
  routerNeglect: false,
  // re-evaluates redirect when auth state changes
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    debugPrint('redirect called: ${state.matchedLocation}');
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final onLogin = state.matchedLocation == '/login';
    final onLoading = state.matchedLocation == '/loading';

    // send logged-out users to login
    if (!isLoggedIn && !onLogin) return '/login';

    // send already-logged-in users away from login
    if (isLoggedIn && onLogin) return '/loading';

    // if init hasn't run yet (e.g. user refreshed on a sub-route), run it first
    if (isLoggedIn && !onLoading && !_appInitialized) return '/loading';

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
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const HomeScreen()),
    ),
    GoRoute(
      path: '/calorie-calculator',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const CalorieCalculator()),
      routes: [
        GoRoute(
          path: 'results',
          // redirect back to calculator if the screen is accessed directly
          // (the Results widget needs params that can't come from a URL)
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
      path: '/food-logging',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const FoodLogging()),
      routes: [
        GoRoute(
          path: 'analytics',
          // redirect back if accessed directly without params
          redirect: (context, state) =>
              state.extra == null ? '/food-logging' : null,
          pageBuilder: (context, state) {
            final p = state.extra as Map<String, dynamic>;
            return _slidePage(
              key: state.pageKey,
              child: FoodLoggingChartsScreen(
                initialDate: p['initialDate'] as DateTime,
                onDateChanged: p['onDateChanged'] as void Function(DateTime)?,
              ),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/reminders',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const Reminders()),
    ),
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
      path: '/explore',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const Explore()),
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

  Future<void> _initApp() async {
    // Set initialized before navigating so the redirect doesn't bounce back to /loading
    _appInitialized = true;

    // Navigate immediately so HomeScreen can show its skeletonizer while data loads
    final uri = Uri.base;
    final path = uri.path.replaceFirst('/level_up', '');
    final destination = (path.isNotEmpty && path != '/loading') ? path : '/';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(destination);
    });

    await userManager.loadUserData();

    userManager.updateUtcOffset();
    expNotifier.value = currentUserData?.expPoints ?? 0;

    // sync theme color before any screen renders
    if (currentUserData != null) {
      appColorNotifier.value = currentUserData!.appColor;
    }

    // initialize FCM in the background so it doesn't delay screen render
    if (mounted) FcmService.initialize(context);

    appReadyNotifier.value = true;
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
