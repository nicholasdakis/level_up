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
import 'utility/web_utils_stub.dart'
    if (dart.library.js_interop) 'utility/web_utils_web.dart'
    as web_fcm;

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

// slides in on push, instant on pop so there's no reverse animation after swipe-back or back button
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
    if (isLoggedIn && !onLoading && !appInitialized) return '/loading';

    // init is done and user is still on loading
    // restores sub-route on web page refresh (e.g. /food-logging), falls back to /
    if (isLoggedIn && onLoading && appInitialized) {
      final uri = Uri.base;
      final path = uri.path.replaceFirst('/level_up', '');
      return (path.isNotEmpty && path != '/loading') ? path : '/';
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
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          NoTransitionPage(key: state.pageKey, child: const HomeScreen()),
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

        // Blend color.withAlpha(200) over the dark gradient edge to get the exact appbar color
        // This is what the notch shows since Flutter's safe area leaves it as the HTML background
        const alpha = 200 / 255;
        Color blendOver(Color fg, Color bg) => Color.fromARGB(
          255,
          (fg.r * alpha + bg.r * (1 - alpha)).round(),
          (fg.g * alpha + bg.g * (1 - alpha)).round(),
          (fg.b * alpha + bg.b * (1 - alpha)).round(),
        );
        final notch = toHex(blendOver(base, dark));

        web_fcm.setAppColor('${toHex(dark)}|${toHex(mid)}|$notch');
        debugPrint('setAppColor called with notch: $notch');
      } catch (e) {
        debugPrint('setAppColor failed: $e');
      }
    }

    if (mounted) FcmService.initialize(context);

    appReadyNotifier.value = true;

    // set flag then refresh the router so the redirect rule sends the user to /
    appInitialized = true;
    appRouter.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
