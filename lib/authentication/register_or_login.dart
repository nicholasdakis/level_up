import 'package:flutter/material.dart';
import '../globals.dart';
import 'auth_services.dart';
import 'dart:ui';
import '../utility/responsive.dart';

class RegisterOrLogin extends StatefulWidget {
  const RegisterOrLogin({super.key});

  @override
  State<RegisterOrLogin> createState() => _RegisterOrLoginState();
}

class _RegisterOrLoginState extends State<RegisterOrLogin> {
  // Keep track of entered email and password fields
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? notifyingMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          Responsive.buttonHeight(context, 120),
        ), // Scale based on device
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF121212),
          centerTitle: true,
          toolbarHeight: Responsive.buttonHeight(
            context,
            120,
          ), // Scale based on device
          elevation: 0,
          title: createTitle("Welcome!", context),
          flexibleSpace: Center(
            child: Padding(
              padding: EdgeInsets.only(
                top: Responsive.padding(context, 20),
              ), // Scale based on device
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(
            Responsive.padding(context, 16),
          ), // Scale based on device
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enter Email field
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Email",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              SizedBox(
                height: Responsive.padding(context, 15),
              ), // Scale based on device
              // Enter Password field
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Password",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              SizedBox(
                height: Responsive.padding(context, 30),
              ), // Scale based on device
              // Login and Register with Email buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: Responsive.buttonHeight(
                        context,
                        60,
                      ), // Scale based on device
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 30),
                            ), // Scale based on device
                          ),
                          backgroundColor: const Color(0xFF2A2A2A),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.black,
                            width: Responsive.scale(
                              context,
                              1,
                            ), // Scale based on device
                          ),
                        ),
                        onPressed: () async {
                          try {
                            await authService.value.signUpWithEmail(
                              email: emailController.text.trim(),
                              password: passwordController.text.trim(),
                            );
                            if (!mounted) return;
                            setState(() {
                              notifyingMessage = "Registration successful";
                            });
                          } catch (e) {
                            if (!mounted) return;
                            setState(() {
                              notifyingMessage = "Registration error: $e";
                            });
                          }
                        },
                        child: buttonText(
                          "Register",
                          context,
                          24,
                        ), // Scale based on device
                      ),
                    ),
                  ),
                  SizedBox(
                    width: Responsive.padding(context, 12),
                  ), // Scale based on device
                  Expanded(
                    child: SizedBox(
                      height: Responsive.buttonHeight(
                        context,
                        60,
                      ), // Scale based on device
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 30),
                            ), // Scale based on device
                          ),
                          backgroundColor: const Color(0xFF2A2A2A),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.black,
                            width: Responsive.scale(
                              context,
                              1,
                            ), // Scale based on device
                          ),
                        ),
                        onPressed: () async {
                          try {
                            await authService.value.signInWithEmail(
                              email: emailController.text.trim(),
                              password: passwordController.text.trim(),
                            );
                            if (!mounted) return;
                            setState(() {
                              notifyingMessage = "Login successful";
                            });
                          } catch (e) {
                            if (!mounted) return;
                            setState(() {
                              notifyingMessage = "Login error: $e";
                            });
                          }
                        },
                        child: buttonText(
                          "Login",
                          context,
                          24,
                        ), // Scale based on device
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: Responsive.padding(
                  context,
                  8,
                ), // spacing between buttons and notifying message
              ),
              Text(
                // notify the user about any problems with registering / login
                notifyingMessage ?? "",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: Responsive.font(context, 14),
                ), // Scale based on device
              ),
            ],
          ),
        ),
      ),
    );
  }
}
