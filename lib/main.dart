import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pwa_install/pwa_install.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/ad_service.dart';
import 'firebase_options.dart';
import 'globals.dart';
import 'router.dart';
import 'utility/confetti.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'utility/remove_splash_stub.dart'
    if (dart.library.js_interop) 'utility/remove_splash_web.dart';

Future<void> main() async {
  final stopwatch = Stopwatch()..start();
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
  runApp(const MyApp());

  if (!kIsWeb) {
    MobileAds.instance.initialize().then((_) => adService.loadRewardedAd());
  }

  // wait until the first frame is fully painted before fading out the splash
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (kIsWeb) {
      removeSplash();
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) {
        return ValueListenableBuilder<Color>(
          valueListenable: appColorNotifier,
          builder: (context, color, _) {
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
                    backgroundColor: WidgetStateProperty.all(
                      color.withAlpha(200),
                    ),
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
      },
    );
  }
}
