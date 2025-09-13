import 'package:flutter/material.dart';
import 'auth_services.dart';
import '../home_screen.dart';
import 'register_or_login.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthenticationGate extends StatelessWidget {
  const AuthenticationGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService
          .value
          .authStateChanges, // Check if there is a logged-in user
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // waiting for the check
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // user is logged in
          return const HomeScreen();
        }
        return const RegisterOrLogin(); // user is not logged in
      },
    );
  }
}
