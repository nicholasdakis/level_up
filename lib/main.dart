import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'authentication/auth_gate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'utility/notification_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Setup notifications and timezones
  await initializeNotificationsAndTimezones();

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
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.dark(
              primary: Colors.white, // text and buttons
              surface: Color(0xFF1E1E1E), // scaffold background
            ),
            scaffoldBackgroundColor: const Color(0xFF1E1E1E),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
            ),
            textButtonTheme: TextButtonThemeData(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: Color(0xFF2A2A2A),
              contentTextStyle: TextStyle(color: Colors.white),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(
                  const Color(0xFF2A2A2A),
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
  }
}
