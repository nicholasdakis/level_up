import 'dart:ui';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../globals.dart';
import '../utility/responsive.dart';

Future<void> showProWelcomeOverlay(BuildContext context, Color appColor) async {
  final controller = ConfettiController(duration: const Duration(seconds: 5));
  controller.play();
  await showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) =>
        _ProWelcomeOverlay(appColor: appColor, confettiController: controller),
  );
  controller.dispose();
}

class _ProWelcomeOverlay extends StatefulWidget {
  final Color appColor;
  final ConfettiController confettiController;
  const _ProWelcomeOverlay({
    required this.appColor,
    required this.confettiController,
  });

  @override
  State<_ProWelcomeOverlay> createState() => _ProWelcomeOverlayState();
}

class _ProWelcomeOverlayState extends State<_ProWelcomeOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final AnimationController _exitCtrl;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _exitOpacity = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic));
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _exitCtrl.forward();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Widget _shimmerText(
    BuildContext context,
    String text,
    double fontSize, {
    FontWeight weight = FontWeight.w800,
  }) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, _) {
        final pos = _shimmerCtrl.value;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.5 + pos * 3.5, 0),
            end: Alignment(-0.5 + pos * 3.5, 0),
            colors: const [
              Color(0xFFB8860B),
              Color(0xFFFFD700),
              Colors.white,
              Color(0xFFFFD700),
              Color(0xFFB8860B),
            ],
            stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
          ).createShader(bounds),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: fontSize,
              fontWeight: weight,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = lightenColor(widget.appColor, 0.45);
    final dim = lightenColor(widget.appColor, 0.35);
    final faint = lightenColor(widget.appColor, 0.3);

    final perks = [
      (
        icon: HugeIcons.strokeRoundedStar,
        title: '1.2× XP Forever',
        desc:
            'Every action earns 20% more XP. Now you\'ll level up faster than ever.',
      ),
      (
        icon: HugeIcons.strokeRoundedShield01,
        title: '3 Streak Shields / Month',
        desc:
            'Missed a day? One tap restores your streak instantly. Your shield count refills every month.',
      ),
      (
        icon: HugeIcons.strokeRoundedAnalytics01,
        title: 'Full Analytics History',
        desc: 'See your entire health journey with no 14-day limit.',
      ),
      (
        icon: HugeIcons.strokeRoundedPaintBoard,
        title: 'Unlimited Themes',
        desc:
            'Pick any color with the full color picker. Make the app completely yours.',
      ),
    ];

    return AnimatedBuilder(
      animation: _exitCtrl,
      builder: (_, child) => Opacity(opacity: _exitOpacity.value, child: child),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _dismiss,
          behavior: HitTestBehavior.opaque,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withAlpha(180),
              child: Stack(
                children: [
                  // Confetti from top center
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: widget.confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      numberOfParticles: 40,
                      gravity: 0.25,
                      colors: const [
                        Color(0xFFFFD700),
                        Color(0xFFFFA500),
                        Colors.white,
                        Color(0xFFFFE066),
                      ],
                    ),
                  ),

                  SafeArea(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.centeredHorizontalPadding(
                          context,
                          28,
                        ),
                        vertical: Responsive.height(context, 32),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: Responsive.height(context, 20)),

                          // Big PRO badge
                          Center(
                            child:
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.width(context, 32),
                                    vertical: Responsive.height(context, 12),
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFFA500),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      Responsive.scale(context, 12),
                                    ),
                                  ),
                                  child: _shimmerText(
                                    context,
                                    'PRO',
                                    Responsive.font(context, 28),
                                  ),
                                ).animate().scale(
                                  duration: 500.ms,
                                  curve: Curves.elasticOut,
                                ),
                          ),

                          SizedBox(height: Responsive.height(context, 28)),

                          // Welcome text with shimmer
                          _shimmerText(
                                context,
                                'Welcome to\nLevel Up! Pro',
                                Responsive.font(context, 34),
                              )
                              .animate()
                              .fadeIn(delay: 200.ms, duration: 400.ms)
                              .slideY(begin: 0.1),

                          SizedBox(height: Responsive.height(context, 12)),

                          Text(
                            'Your subscription is active. Here\'s everything you just unlocked.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 14),
                              color: dim,
                              height: 1.5,
                            ),
                          ).animate().fadeIn(delay: 350.ms, duration: 400.ms),

                          SizedBox(height: Responsive.height(context, 36)),

                          // Perk cards
                          for (int i = 0; i < perks.length; i++) ...[
                            Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.width(context, 16),
                                    vertical: Responsive.height(context, 16),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(8),
                                    borderRadius: BorderRadius.circular(
                                      Responsive.scale(context, 14),
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withAlpha(15),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(
                                          Responsive.scale(context, 10),
                                        ),
                                        decoration: BoxDecoration(
                                          color: accent.withAlpha(20),
                                          borderRadius: BorderRadius.circular(
                                            Responsive.scale(context, 10),
                                          ),
                                        ),
                                        child: HugeIcon(
                                          icon: perks[i].icon,
                                          color: accent,
                                          size: Responsive.scale(context, 22),
                                        ),
                                      ),
                                      SizedBox(
                                        width: Responsive.width(context, 14),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              perks[i].title,
                                              style: GoogleFonts.manrope(
                                                fontSize: Responsive.font(
                                                  context,
                                                  14,
                                                ),
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(
                                              height: Responsive.height(
                                                context,
                                                4,
                                              ),
                                            ),
                                            Text(
                                              perks[i].desc,
                                              style: GoogleFonts.manrope(
                                                fontSize: Responsive.font(
                                                  context,
                                                  12,
                                                ),
                                                color: faint,
                                                height: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .animate()
                                .fadeIn(
                                  delay: Duration(milliseconds: 400 + i * 100),
                                  duration: 350.ms,
                                )
                                .slideY(begin: 0.05),
                            if (i < perks.length - 1)
                              SizedBox(height: Responsive.height(context, 10)),
                          ],

                          SizedBox(height: Responsive.height(context, 40)),

                          Text(
                            'Tap anywhere to continue',
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 12),
                              color: Colors.white38,
                            ),
                          ).animate().fadeIn(delay: 900.ms, duration: 400.ms),

                          SizedBox(height: Responsive.height(context, 20)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
