import 'package:flutter/material.dart';
import 'package:level_up/utility/responsive.dart';
import 'package:level_up/globals.dart';

class SettingsIconButton extends StatefulWidget {
  final VoidCallback onTap;

  const SettingsIconButton({super.key, required this.onTap});

  @override
  State<SettingsIconButton> createState() => _SettingsIconButtonState();
}

class _SettingsIconButtonState extends State<SettingsIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  // Initialize the glow animation controller
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  // Prevent memory leaks
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Pulse the glow forward and back on tap, then open the drawer
  void _handleTap() {
    _controller.forward(from: 0).then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final color = appColorNotifier.value; // matches HomeScreen color source

    return Padding(
      padding: EdgeInsets.only(
        top: Responsive.height(context, 20),
        right: Responsive.width(context, 20),
      ),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: _handleTap,
            child: AnimatedScale(
              scale: _isPressed ? 0.92 : 1.0, // press-down feel on tap
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: Container(
                padding: EdgeInsets.all(Responsive.width(context, 11)),
                decoration: BoxDecoration(
                  // Mirrors _frostedButtonShell fill pattern
                  color: darkenColor(
                    color,
                    0.075,
                  ).withValues(alpha: 0.16 + _glowAnimation.value * 0.12),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 16),
                  ),
                  border: Border.all(
                    // Same brightness as customButton border
                    color: lightenColor(
                      color,
                      0.30,
                    ).withValues(alpha: 0.30 + _glowAnimation.value * 0.45),
                    width: Responsive.scale(context, 1.5),
                  ),
                  boxShadow: [
                    // Strong app color glow on tap
                    BoxShadow(
                      color: color.withValues(
                        alpha: 0.25 + _glowAnimation.value * 0.60,
                      ),
                      blurRadius: Responsive.scale(context, 24),
                      spreadRadius:
                          Responsive.scale(context, 4) * _glowAnimation.value,
                    ),
                    // Depth shadow that mirrors _frostedButtonShell boxShadow
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: Responsive.scale(context, 16),
                      offset: Offset(0, Responsive.scale(context, 4)),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                // Icon alpha matches customButton icon pattern
                child: Icon(
                  Icons.manage_accounts_outlined,
                  size: Responsive.font(context, 46),
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
