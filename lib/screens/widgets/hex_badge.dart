import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '/globals.dart';

// Pointy-top hexagon clip, -30 degree offset rotates the first vertex to the top
class _HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(cx, cy);
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 180) * (60 * i - 30);
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_HexClipper old) => false;
}

// Stroked hexagon border, inset by half strokeWidth so it doesn't get clipped at the edges
class _HexBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _HexBorderPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(cx, cy) - strokeWidth / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 180) * (60 * i - 30);
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_HexBorderPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class HexBadge extends StatelessWidget {
  final IconData icon;
  final Color appColor;
  final double size;
  // false = filled/solid (active or in-progress), true = outline only (fully claimed, settled)
  final bool allClaimed;
  final VoidCallback? onTap;

  const HexBadge({
    super.key,
    required this.icon,
    required this.appColor,
    required this.size,
    required this.allClaimed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.38;
    final borderWidth = size * 0.04;

    // Filled when active/in-progress, outline-only when fully claimed
    final bgColor = allClaimed ? Colors.transparent : appColor.withAlpha(160);
    final borderColor = allClaimed
        ? cardColors(appColor).iconBorder
        : onTheme(appColor).withAlpha(200);
    final iconColor = allClaimed
        ? onTheme(appColor).withAlpha(120)
        : onTheme(appColor);

    Widget badge = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!allClaimed)
            ClipPath(
              clipper: _HexClipper(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [bgColor.withAlpha(180), bgColor.withAlpha(230)],
                  ),
                ),
              ),
            ),
          CustomPaint(
            size: Size(size, size),
            painter: _HexBorderPainter(
              color: borderColor,
              strokeWidth: borderWidth,
            ),
          ),
          HugeIcon(icon: icon, color: iconColor, size: iconSize),
        ],
      ),
    );

    if (onTap != null) {
      badge = GestureDetector(onTap: onTap, child: badge);
    }

    return badge;
  }
}
