import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pwa_install/pwa_install.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'services/ad_service.dart';
import 'firebase_options.dart';
import 'globals.dart';
import 'router.dart';
import 'utility/confetti.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'utility/remove_splash_stub.dart'
    if (dart.library.js_interop) 'utility/remove_splash_web.dart';
import 'utility/viewport_height_stub.dart'
    if (dart.library.js_interop) 'utility/viewport_height_web.dart';
import 'services/user_data_manager.dart' show backendBaseUrl, defaultAppColor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/user_data_provider.dart';
import 'screens/level_up_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    // extend flutter's canvas behind the status bar and nav bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // make both bars fully transparent so app content shows through
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }
  // Removes the # from URLs so paths look like /food-logging instead of /#/food-logging
  usePathUrlStrategy();
  // Initialize PWA install prompt so users can install the app from the settings drawer
  // try-catch because the pwa_install package crashes in dev mode (flutter run doesn't serve manifest.json)
  try {
    PWAInstall().setup(installCallback: () {});
  } catch (e) {
    if (kDebugMode) debugPrint('PWA install setup skipped: $e');
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseAnalytics.instance; // initialize analytics
  confettiControllerinit();
  appLaunchUri = Uri.base;
  listenToViewportHeight((h) => viewportHeightNotifier.value = h);
  runApp(const ProviderScope(child: MyApp()));

  if (!kIsWeb) {
    adService.initialize();
  }

  // wait until the first frame is fully painted before fading out the splash
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (kIsWeb) {
      removeSplash();
    }
  });
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  // start as true so the first connectivity event always triggers _onReconnect if online
  bool _wasOffline = true;
  int _lastKnownLevel = -1;
  late VoidCallback _levelUpListener;

  @override
  void initState() {
    super.initState();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final online = !results.contains(ConnectivityResult.none);
      if (online && _wasOffline) {
        await _onReconnect();
      }
      _wasOffline = !online;
    });

    // Listens on userDataNotifier so level-ups are caught regardless of which
    // screen awards XP. _lastKnownLevel starts at -1 and is set to the real
    // level on the first notification where data is present, so login never
    // triggers the overlay. After that, any increase fires showLevelUpOverlay.
    _levelUpListener = () {
      final newLevel = currentUserData?.level ?? 0;
      // guests have no real level progression
      if (isGuest) return;
      // wait until backend data is fully loaded before tracking anything
      if (!appReadyNotifier.value) {
        // reset baseline on logout so the next login captures a fresh one
        _lastKnownLevel = -1;
        return;
      }
      if (_lastKnownLevel == -1) {
        // capture the baseline on the first notification after real data is ready
        _lastKnownLevel = newLevel;
        return;
      }
      if (newLevel > _lastKnownLevel) {
        _lastKnownLevel = newLevel;
        final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          // postFrameCallback avoids showing the overlay mid-build
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final c = appRouter.routerDelegate.navigatorKey.currentContext;
            if (c != null && c.mounted) {
              await showLevelUpOverlay(
                c,
                newLevel,
                ref.read(userDataProvider).value?.appColor ?? defaultAppColor,
              );
            }
          });
        }
      } else {
        _lastKnownLevel = newLevel;
      }
    };
    userDataNotifier.addListener(_levelUpListener);
  }

  Future<void> _onReconnect() async {
    // check version first before doing anything else
    try {
      final response = await http
          .get(Uri.parse('$backendBaseUrl/app_config'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final minVersion =
            (jsonDecode(response.body) as Map)['min_version'] as String?;
        if (minVersion != null) {
          final info = await PackageInfo.fromPlatform();
          List<int> parts(String v) => v.split('.').map(int.parse).toList();
          // strip build metadata (e.g. "1.1.4+35" -> "1.1.4") before comparing
          final cur = parts(info.version.split('+').first);
          final req = parts(minVersion);
          for (int i = 0; i < req.length; i++) {
            final c = i < cur.length ? cur[i] : 0;
            if (c < req[i]) {
              isAppOutdated = true;
              appRouter.refresh();
              return;
            }
            if (c > req[i]) break;
          }
        }
      }
    } catch (_) {}

    // version is fine, retry loading user data if it failed while offline
    if (appInitialized && userManager.lastLoadFailed) {
      await userManager.loadUserData();
      if (currentUserData != null && !userManager.lastLoadFailed) {
        expNotifier.value = currentUserData!.expPoints;
        userDataNotifier.notifyListeners();
        appReadyNotifier.value = true;
      }
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    userDataNotifier.removeListener(_levelUpListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        ref.watch(userDataProvider).value?.appColor ?? defaultAppColor;
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          // go_router handles all navigation
          routerConfig: appRouter,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.dark(
              primary: Colors.white, // text and buttons
              surface: color.withAlpha(200),
            ),
            scaffoldBackgroundColor: color.withAlpha(200),

            dialogTheme: DialogThemeData(
              backgroundColor: color.withAlpha(
                170,
              ), // main dialog theme transparency
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: Colors.white.withAlpha(100),
                  width: 1.5,
                ),
              ),
              titleTextStyle: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              contentTextStyle: GoogleFonts.manrope(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),

            appBarTheme: AppBarTheme(
              backgroundColor: color.withAlpha(200),
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
            ),
            textButtonTheme: TextButtonThemeData(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: darkenColor(color, 0.025),
              contentTextStyle: TextStyle(color: Colors.white),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(color.withAlpha(200)),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              hintStyle: const TextStyle(color: Colors.white70),
              labelStyle: const TextStyle(color: Colors.white),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
}
