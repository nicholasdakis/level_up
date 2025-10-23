import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../globals.dart';
import '../user/user_data.dart';
import '../user/user_data_manager.dart';

class Reminders extends StatefulWidget {
  const Reminders({super.key});

  @override
  State<Reminders> createState() => _RemindersState();
}

class _RemindersState extends State<Reminders> {
  @override
  Widget build(BuildContext context) {
    double screenHeight =
        1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth =
        1.sw; // Make widgets the size of the user's personal screen size
    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
      // Header box
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        centerTitle: true,
        toolbarHeight: screenHeight * 0.15,
        title: createTitle("Reminders", screenWidth),
      ),
      body: Center(
        // Temporary buttons for testing experience gain
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () => userManager.updateExpPoints(1),
              child: const Text("Gain 1 XP"),
            ),
            ElevatedButton(
              onPressed: () => userManager.updateExpPoints(5),
              child: const Text("Gain 5 XP"),
            ),
            ElevatedButton(
              onPressed: () => userManager.updateExpPoints(10),
              child: const Text("Gain 10 XP"),
            ),
            ElevatedButton(
              onPressed: () => userManager.updateExpPoints(50),
              child: const Text("Gain 50 XP"),
            ),
            ElevatedButton(
              onPressed: () => userManager.updateExpPoints(100),
              child: const Text("Gain 100 XP"),
            ),
          ],
        ),
      ),
    );
  }
}
