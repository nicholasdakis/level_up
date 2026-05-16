import 'dart:math';
import 'dart:ui' as ui;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

late ConfettiController dailyRewardConfettiController;
late ConfettiController badgesConfettiController;
late ConfettiController checkinConfettiController;

ConfettiWidget buildDailyRewardConfetti(
  ConfettiController dailyRewardConfettiController,
) {
  return ConfettiWidget(
    confettiController: dailyRewardConfettiController,

    // Direction / shape
    blastDirectionality: BlastDirectionality.explosive, // all directions
    blastDirection: pi / 2,
    emissionFrequency: 0.02, // how often new particles spawn
    numberOfParticles: 25, // how many per blast
    gravity: 0.3, // how fast they fall
    colors: [Colors.yellow, Colors.green, Colors.blue, Colors.purple],

    // Appearance
    shouldLoop: false, // play once
    maxBlastForce: 20, // max speed
    minBlastForce: 10, // min speed
    particleDrag: 0.10, // air resistance
    // Shape / size
    createParticlePath: null, // default rectangle
  );
}

ConfettiWidget buildCheckinConfetti() {
  return ConfettiWidget(
    confettiController: checkinConfettiController,
    blastDirectionality: BlastDirectionality.directional,
    blastDirection: pi / 2,
    emissionFrequency: 1,
    numberOfParticles: 6,
    gravity: 0.6,
    shouldLoop: false,
    maxBlastForce: 30,
    minBlastForce: 15,
    particleDrag: 0.03,
    colors: const [
      Color(0xFFFF4D6D),
      Color(0xFFFFD60A),
      Color(0xFF80ED99),
      Color(0xFF48CAE4),
      Color(0xFFFF9E00),
    ],
    createParticlePath: _buildCheckinShape,
  );
}

ui.Path _buildCheckinShape(Size size) {
  final which = DateTime.now().microsecond % 3;
  final p = ui.Path();
  if (which == 0) {
    p.addOval(Rect.fromLTWH(0, 0, size.width, size.height));
  } else if (which == 1) {
    p.moveTo(size.width / 2, 0);
    p.lineTo(size.width, size.height / 2);
    p.lineTo(size.width / 2, size.height);
    p.lineTo(0, size.height / 2);
    p.close();
  } else {
    p.addRect(Rect.fromLTWH(0, 0, size.width * 0.3, size.height));
  }
  return p;
}

void confettiControllerinit() {
  // Initialize all controllers
  dailyRewardConfettiController = ConfettiController(
    duration: Duration(milliseconds: 300),
  );
  badgesConfettiController = ConfettiController(
    duration: Duration(milliseconds: 500),
  );
  checkinConfettiController = ConfettiController(
    duration: Duration(milliseconds: 100),
  );
}
