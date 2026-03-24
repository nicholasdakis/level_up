import 'package:flutter/material.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

late ConfettiController badgesConfettiController;

class Badges extends StatefulWidget {
  const Badges({super.key});

  @override
  State<Badges> createState() => _BadgesState();
}

class _BadgesState extends State<Badges> {
  @override
  void initState() {
    super.initState();
    // Initialize the confetti controller for this screen
    badgesConfettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    // Dispose controller to avoid memory leaks
    badgesConfettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Body color
        // Header box
        appBar: AppBar(
          backgroundColor: darkenColor(
            appColorNotifier.value,
            0.025,
          ), // Header color
          centerTitle: true,
          toolbarHeight: Responsive.buttonHeight(context, 120),
          title: createTitle("Badges", context),
        ),
        body: Stack(
          // Stack added so confetti can appear on top of buttons
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Badges tab"),

                  // Example buttons to test confetti
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 20),
                    ),
                    onPressed: () {
                      badgesConfettiController.play();
                    },
                    child: const Text(
                      'Click me to make up for the lack of badges.',
                    ),
                  ),
                ],
              ),
            ),
            // Confetti widget added here so it appears above buttons
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: Responsive.width(context, 200),
                child: ConfettiWidget(
                  confettiController: badgesConfettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  blastDirection: -pi / 4,
                  emissionFrequency: 0.9,
                  numberOfParticles: 1,
                  gravity: 1,
                  colors: [
                    Colors.yellow,
                    Colors.green,
                    Colors.blue,
                    Colors.purple,
                  ],
                  shouldLoop: false,
                  maxBlastForce: 150,
                  minBlastForce: 100,
                  particleDrag: 0.04,
                  createParticlePath: null, // default rectangle
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
