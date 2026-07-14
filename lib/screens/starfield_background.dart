import 'dart:math' as math;
import 'package:flutter/material.dart';

class StarfieldBackground extends StatefulWidget {
  final Widget child;
  const StarfieldBackground({super.key, required this.child});

  @override
  State<StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) =>
              CustomPaint(painter: _StarfieldPainter(time: _ctrl.value)),
        ),
        widget.child,
      ],
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final double time;
  _StarfieldPainter({required this.time});

  static const _stars = [
    (0.08, 0.11, 1.5, 0.00),
    (0.21, 0.04, 1.0, 0.23),
    (0.35, 0.14, 2.0, 0.47),
    (0.52, 0.07, 1.3, 0.61),
    (0.67, 0.03, 1.8, 0.14),
    (0.81, 0.12, 1.1, 0.78),
    (0.93, 0.06, 1.5, 0.33),
    (0.05, 0.28, 0.9, 0.55),
    (0.17, 0.35, 1.7, 0.09),
    (0.29, 0.22, 1.2, 0.82),
    (0.44, 0.31, 1.0, 0.41),
    (0.58, 0.19, 2.0, 0.67),
    (0.73, 0.27, 1.3, 0.19),
    (0.88, 0.33, 1.6, 0.93),
    (0.96, 0.21, 0.9, 0.37),
    (0.12, 0.52, 1.8, 0.72),
    (0.26, 0.61, 1.0, 0.05),
    (0.41, 0.48, 1.4, 0.58),
    (0.55, 0.57, 2.0, 0.29),
    (0.69, 0.44, 1.1, 0.84),
    (0.83, 0.55, 1.5, 0.16),
    (0.04, 0.72, 1.0, 0.63),
    (0.19, 0.78, 1.8, 0.44),
    (0.33, 0.69, 1.3, 0.88),
    (0.47, 0.81, 0.9, 0.22),
    (0.62, 0.74, 1.6, 0.51),
    (0.76, 0.68, 1.4, 0.07),
    (0.91, 0.76, 1.1, 0.76),
    (0.10, 0.89, 1.5, 0.39),
    (0.24, 0.93, 1.0, 0.95),
    (0.38, 0.87, 2.0, 0.18),
    (0.53, 0.91, 1.3, 0.64),
    (0.66, 0.85, 0.9, 0.30),
    (0.79, 0.92, 1.7, 0.53),
    (0.94, 0.88, 1.4, 0.87),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final (rx, ry, r, phase) in _stars) {
      final twinkle = (math.sin((time + phase) * math.pi * 2) + 1) / 2;
      final alpha = (30 + twinkle * 80).round();
      final radius = r * (0.6 + twinkle * 0.4);
      paint.color = Colors.white.withAlpha((alpha * 0.2).round());
      canvas.drawCircle(
        Offset(rx * size.width, ry * size.height),
        radius * 2.5,
        paint,
      );
      paint.color = Colors.white.withAlpha(alpha);
      canvas.drawCircle(
        Offset(rx * size.width, ry * size.height),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) => old.time != time;
}
