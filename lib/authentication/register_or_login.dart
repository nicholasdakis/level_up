import 'package:flutter/material.dart';
import '../globals.dart';
import 'auth_services.dart';
import '../utility/responsive.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        preferredSize: Size.fromHeight(Responsive.buttonHeight(context, 120)),
        child: AppBar(
          scrolledUnderElevation:
              0, // So the appBar does not change color when the user scrolls down
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF121212),
          centerTitle: true,
          toolbarHeight: Responsive.buttonHeight(context, 120),
          elevation: 0,
          title: createTitle("Welcome!", context),
          flexibleSpace: Center(
            child: Padding(
              padding: EdgeInsets.only(top: Responsive.padding(context, 20)),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(Responsive.padding(context, 16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App logo
              SizedBox(
                height: Responsive.buttonHeight(context, 240),
                child: Image.asset("assets/app_logo.png", fit: BoxFit.contain),
              ),
              // Enter Email field
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Email",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              SizedBox(height: Responsive.padding(context, 15)),
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
              SizedBox(height: Responsive.padding(context, 30)),
              // Login and Register with Email buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: Responsive.buttonHeight(context, 60),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 30),
                            ),
                          ),
                          backgroundColor: const Color(0xFF2A2A2A),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.black,
                            width: Responsive.scale(context, 1),
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
                        child: buttonText("Register", context, 24),
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.padding(context, 12)),
                  Expanded(
                    child: SizedBox(
                      height: Responsive.buttonHeight(context, 60),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 30),
                            ),
                          ),
                          backgroundColor: const Color(0xFF2A2A2A),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.black,
                            width: Responsive.scale(context, 1),
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
                          } on FirebaseAuthException catch (e) {
                            if (!mounted) return;

                            if (e.code == 'invalid-credential') {
                              setState(() {
                                notifyingMessage =
                                    "Login error: Invalid email or password. If your credentials are correct and your account has used 'Continue with Google' as a login method, 'Reset Password' will allow both login methods to work in the future. Alternatively, you can continue logging in using 'Continue with Login'.";
                              });
                            } else {
                              setState(() {
                                notifyingMessage = "Login error: $e";
                              });
                            }
                          } catch (e) {
                            if (!mounted) return;
                            setState(() {
                              notifyingMessage = "Login error: $e";
                            });
                          }
                        },
                        child: buttonText("Login", context, 24),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: Responsive.padding(
                  context,
                  20,
                ), // spacing between buttons and notifying message
              ),
              SizedBox(height: Responsive.padding(context, 10)),

              // Divider section
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                            right: Responsive.padding(context, 12),
                          ),
                          height: 1,
                          color: Colors.white24,
                        ),
                      ),
                      Text(
                        "Other Options",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: Responsive.font(context, 14),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                            left: Responsive.padding(context, 12),
                          ),
                          height: 1,
                          color: Colors.white24,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.padding(context, 16)),
                ],
              ),
              // Reset password button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    if (emailController.text.isEmpty) {
                      setState(() {
                        notifyingMessage =
                            "Enter your email to reset password.";
                      });
                      return;
                    }
                    try {
                      await authService.value.resetPassword(
                        email: emailController.text.trim(),
                      );
                      setState(() {
                        notifyingMessage =
                            "Success: Password reset email sent to ${emailController.text.trim()}.";
                      });
                    } catch (e) {
                      setState(() {
                        notifyingMessage = "Error: $e";
                      });
                    }
                  },
                  child: Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: Responsive.font(context, 12),
                    ),
                  ),
                ),
              ),

              Align(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () async {
                    try {
                      await authService.value.signInWithGoogle();
                      if (!mounted) return;
                      setState(() {
                        notifyingMessage = "Google login successful";
                      });
                    } catch (e) {
                      if (!mounted) return;
                      setState(() {
                        notifyingMessage = "Google sign-in failed: $e";
                      });
                    }
                  },
                  child: SvgPicture.asset(
                    "assets/continue_with_google.svg",
                    height: Responsive.buttonHeight(context, 60),
                  ),
                ),
              ),

              SizedBox(
                height: Responsive.padding(
                  context,
                  20,
                ), // spacing between buttons and notifying message
              ),

              Text(
                // notify the user about any problems with registering / login
                notifyingMessage ?? "",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: Responsive.font(context, 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
