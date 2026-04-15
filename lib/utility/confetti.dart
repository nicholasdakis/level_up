import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'dart:math';

late ConfettiController dailyRewardConfettiController;
late ConfettiController badgesConfettiController;

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

void confettiControllerinit() {
  // Initialize all controllers
  dailyRewardConfettiController = ConfettiController(
    duration: Duration(milliseconds: 300),
  );
  badgesConfettiController = ConfettiController(
    duration: Duration(milliseconds: 500),
  );
}
