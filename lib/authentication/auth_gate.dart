import 'package:flutter/material.dart';
import 'auth_services.dart';
import '../home_screen.dart';
import 'register_or_login.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthenticationGate extends StatefulWidget {
  const AuthenticationGate({super.key});

  @override
  State<AuthenticationGate> createState() => _AuthenticationGateState();
}

class _AuthenticationGateState extends State<AuthenticationGate> {
  // Cached so Firebase re-emitting auth state on browser focus events doesn't remount children
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = authService.value.authStateChanges;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream, // Check if there is a logged-in user
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
