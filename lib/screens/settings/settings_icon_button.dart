import 'package:flutter/material.dart';
import 'package:level_up/utility/responsive.dart';

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

  @override
  // Initialize the glow animation controller
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
    return Padding(
      padding: EdgeInsets.only(
        top: Responsive.height(context, 20),
        right: Responsive.width(context, 20),
      ),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return GestureDetector(
            onTap: _handleTap,
            // Frosted glass container with glow pulse on tap
            child: Container(
              padding: EdgeInsets.all(Responsive.width(context, 12)),
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.1 + _glowAnimation.value * 0.15,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: 0.25 + _glowAnimation.value * 0.45,
                  ),
                  width: 1.5,
                ),
                // Outer glow that pulses on tap
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(
                      alpha: _glowAnimation.value * 0.125, // glow strength
                    ),
                    blurRadius: 5 * _glowAnimation.value,
                    spreadRadius: 2 * _glowAnimation.value,
                  ),
                ],
              ),
              child: Icon(
                Icons.manage_accounts_outlined,
                size: Responsive.font(context, 48),
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }
}
