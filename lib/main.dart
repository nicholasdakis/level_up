import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'authentication/auth_gate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import '../globals.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
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
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.dark(
                  primary: Colors.white, // text and buttons
                  surface: color.withAlpha(200),
                ),
                scaffoldBackgroundColor: color.withAlpha(200),
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
              home: const AuthenticationGate(),
            );
          },
        );
      },
    );
  }
}
