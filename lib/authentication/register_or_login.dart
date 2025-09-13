import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../globals.dart';
import '../home_screen.dart';
import 'auth_services.dart';

class RegisterOrLogin extends StatefulWidget {
  const RegisterOrLogin({super.key});

  @override
  State<RegisterOrLogin> createState() => _RegisterOrLoginState();
}

class _RegisterOrLoginState extends State<RegisterOrLogin> {
  // Keep track of enterred email and password fields
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? notifyingMessage;

  @override
  Widget build(BuildContext context) {
    double screenHeight = 1.sh;
    double screenWidth = 1.sw;
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenHeight * 0.15),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF121212),
          centerTitle: true,
          toolbarHeight: screenHeight * 0.5,
          elevation: 0,
          title: createTitle("Welcome!", screenWidth),
          flexibleSpace: Center(
            child: Padding(padding: EdgeInsets.only(top: screenWidth * 0.125)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(screenHeight * 0.02),
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
              const SizedBox(height: 15),
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
              const SizedBox(height: 30),
              // Login and Register with Email buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 0.08.sh,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0.08.sw),
                          ),
                          backgroundColor: const Color(0xFF2A2A2A),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.black,
                            width: 0.003.sw,
                          ),
                        ),
                        onPressed: () async {
                          try {
                            await authService.value.signUpWithEmail(
                              email: emailController.text.trim(),
                              password: passwordController.text.trim(),
                            );
                            setState(() {
                              notifyingMessage = "Registration successful";
                            });
                          } catch (e) {
                            setState(() {
                              notifyingMessage = "Registration error: $e";
                            });
                          }
                        },
                        child: buttonText("Register", 0.05.sw),
                      ),
                    ),
                  ),
                  SizedBox(width: 0.03.sw),
                  Expanded(
                    child: SizedBox(
                      height: 0.08.sh,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0.08.sw),
                          ),
                          backgroundColor: const Color(0xFF2A2A2A),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.black,
                            width: 0.003.sw,
                          ),
                        ),
                        onPressed: () async {
                          try {
                            await authService.value.signInWithEmail(
                              email: emailController.text.trim(),
                              password: passwordController.text.trim(),
                            );
                            setState(() {
                              notifyingMessage = "Login successful";
                            });
                          } catch (e) {
                            setState(() {
                              notifyingMessage = "Login error: $e";
                            });
                          }
                        },
                        child: buttonText("Login", 0.05.sw),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: screenHeight * 0.01,
              ), // spacing between buttons and notifying message
              Text(
                // notify the user about any problems with registering / login
                notifyingMessage ?? "",
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
