import 'dart:math';
import 'dart:ui';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../globals.dart';
import '../providers/food_logs_provider.dart';
import '../providers/user_data_provider.dart';
import '../providers/water_logs_provider.dart';
import '../providers/weight_logs_provider.dart';
import '../utility/responsive.dart';

// Animates the XP bar fill from 0 to progress on mount, with a short entry delay
// so it starts after the rest of the overlay has faded in
class _AnimatedXpBar extends StatefulWidget {
  final double progress;
  final Color accent;
  const _AnimatedXpBar({required this.progress, required this.accent});

  @override
  State<_AnimatedXpBar> createState() => _AnimatedXpBarState();
}

class _AnimatedXpBarState extends State<_AnimatedXpBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => FractionallySizedBox(
        widthFactor: widget.progress * _anim.value,
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: LinearGradient(
              colors: [widget.accent.withAlpha(200), widget.accent],
            ),
          ),
        ),
      ),
    );
  }
}

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

// Returns the rank name, a short description, and the level at which the next rank unlocks (null if max)
({String name, String desc, int? nextAt}) _rank(int level) {
  if (level >= 50) {
    return (name: 'Legendary', desc: 'The top tier. Elite.', nextAt: null);
  }
  if (level >= 30) {
    final n = 50 - level;
    return (
      name: 'Unstoppable',
      desc: '$n ${n == 1 ? 'level' : 'levels'} until Legendary',
      nextAt: 50,
    );
  }
  if (level >= 20) {
    final n = 30 - level;
    return (
      name: 'Dedicated',
      desc: '$n ${n == 1 ? 'level' : 'levels'} until Unstoppable',
      nextAt: 30,
    );
  }
  if (level >= 10) {
    final n = 20 - level;
    return (
      name: 'Committed',
      desc: '$n ${n == 1 ? 'level' : 'levels'} until Dedicated',
      nextAt: 20,
    );
  }
  if (level >= 5) {
    final n = 10 - level;
    return (
      name: 'Rising',
      desc: '$n ${n == 1 ? 'level' : 'levels'} until Committed',
      nextAt: 10,
    );
  }
  final n = 5 - level;
  return (
    name: 'Beginner',
    desc: '$n ${n == 1 ? 'level' : 'levels'} until Rising',
    nextAt: 5,
  );
}

// Call after any XP grant with the level before the grant
// Shows the overlay only if the user actually leveled up
Future<void> handleLevelUpOverlay(
  BuildContext context,
  int levelBefore,
  Color appColor,
  WidgetRef ref,
) async {
  final newLevel = ref.read(userDataProvider).value?.level ?? 0;
  if (newLevel > levelBefore) {
    await showLevelUpOverlay(context, newLevel, appColor, ref);
  }
}

Future<void> showLevelUpOverlay(
  BuildContext context,
  int newLevel,
  Color appColor,
  WidgetRef ref,
) async {
  if (isGuest) return;
  final controller = ConfettiController(duration: const Duration(seconds: 4));
  final accent = lightenColor(appColor, 0.45);
  final dim = lightenColor(appColor, 0.35);
  final xpNeeded = userManager.experienceNeeded ?? 0;
  final currentXp = ref.read(userDataProvider).value?.expPoints ?? 0;
  // xpProgress is how far into the new level the user already is, used to fill the bar
  final xpProgress = xpNeeded > 0
      ? (currentXp / xpNeeded).clamp(0.0, 1.0)
      : 0.0;
  final data = ref.read(userDataProvider).value;

  // only include stats with nonzero values so the grid never shows empty chips
  // all values are peak/best/total, not current state, since this is an accomplishments summary
  final stats = <({IconData icon, String label, String value})>[];
  if (data != null) {
    final totalXp = userManager.totalXpEarned;
    if (totalXp != null && totalXp > 0) {
      stats.add((
        icon: HugeIcons.strokeRoundedStar,
        label: 'Total XP',
        value: _fmt(totalXp),
      ));
    }
    if (data.foodLogStreakBest > 0) {
      stats.add((
        icon: HugeIcons.strokeRoundedFire,
        label: 'Best food streak',
        value: '${data.foodLogStreakBest}d',
      ));
    }
    if (data.dailyClaimStreakBest > 0) {
      stats.add((
        icon: HugeIcons.strokeRoundedCalendar02,
        label: 'Best daily streak',
        value: '${data.dailyClaimStreakBest}d',
      ));
    }
    final foodLogs = ref.read(foodLogsProvider).value ?? [];
    final daysLogged = foodLogs.map((f) => f.date).toSet().length;
    if (daysLogged > 0) {
      stats.add((
        icon: HugeIcons.strokeRoundedNote,
        label: 'Days logged',
        value: _fmt(daysLogged),
      ));
    }
    final waterLogs = ref.read(waterLogsProvider).value ?? {};
    final totalWaterLogs = waterLogs.values.fold(0, (sum, list) => sum + list.length);
    if (totalWaterLogs > 0) {
      stats.add((
        icon: HugeIcons.strokeRoundedDroplet,
        label: 'Water logs',
        value: _fmt(totalWaterLogs),
      ));
    }
    final weightLogs = ref.read(weightLogsProvider).value ?? {};
    if (weightLogs.isNotEmpty) {
      stats.add((
        icon: HugeIcons.strokeRoundedWeightScale,
        label: 'Weigh-ins',
        value: _fmt(weightLogs.length),
      ));
    }
    if (data.referralCount > 0) {
      stats.add((
        icon: HugeIcons.strokeRoundedUserAdd01,
        label: data.referralCount == 1 ? 'Friend referred' : 'Friends referred',
        value: '${data.referralCount}',
      ));
    }
  }

  controller.play();

  // barrierDismissible is false so all taps go through the GestureDetector in
  // _LevelUpDialog, which plays the exit animation before popping
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'level_up',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 400),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
    pageBuilder: (context, anim, secondaryAnim) => _LevelUpDialog(
      confettiController: controller,
      accent: accent,
      dim: dim,
      newLevel: newLevel,
      xpNeeded: xpNeeded,
      currentXp: currentXp,
      xpProgress: xpProgress,
      stats: stats,
    ),
  );

  controller.dispose();
}

// Stateful so it can own the exit AnimationController
// The open animation is handled by showGeneralDialog's transitionBuilder,
// but the close animation (scale down + fade) is driven here before the pop
class _LevelUpDialog extends StatefulWidget {
  final ConfettiController confettiController;
  final Color accent;
  final Color dim;
  final int newLevel;
  final int xpNeeded;
  final int currentXp;
  final double xpProgress;
  final List<({IconData icon, String label, String value})> stats;

  const _LevelUpDialog({
    required this.confettiController,
    required this.accent,
    required this.dim,
    required this.newLevel,
    required this.xpNeeded,
    required this.currentXp,
    required this.xpProgress,
    required this.stats,
  });

  @override
  State<_LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<_LevelUpDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _exitCtrl;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();
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
    _exitCtrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _exitCtrl.forward();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final dim = widget.dim;
    final newLevel = widget.newLevel;
    final r = _rank(newLevel);

    return AnimatedBuilder(
      animation: _exitCtrl,
      builder: (context, child) =>
          Opacity(opacity: _exitOpacity.value, child: child),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _dismiss,
          behavior: HitTestBehavior.opaque,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              color: Colors.black.withAlpha(160),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: widget.confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      blastDirection: pi / 2,
                      emissionFrequency: 0.02,
                      numberOfParticles: 6,
                      gravity: 0.35,
                      shouldLoop: false,
                      maxBlastForce: 20,
                      minBlastForce: 8,
                      particleDrag: 0.1,
                      colors: [
                        Colors.white,
                        Colors.white.withAlpha(180),
                        accent,
                        accent.withAlpha(160),
                        dim,
                      ],
                    ),
                  ),

                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.centeredHorizontalPadding(
                          context,
                          32,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                                icon: HugeIcons.strokeRoundedMedal01,
                                color: accent,
                                size: Responsive.scale(context, 44),
                              )
                              .animate()
                              .scale(
                                begin: const Offset(0, 0),
                                duration: 600.ms,
                                curve: Curves.elasticOut,
                              )
                              .fadeIn(duration: 300.ms),

                          SizedBox(height: Responsive.height(context, 14)),

                          Text(
                            'LEVEL UP!',
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 20),
                              fontWeight: FontWeight.w800,
                              color: accent,
                              letterSpacing: 4,
                            ),
                          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

                          SizedBox(height: Responsive.height(context, 8)),

                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child:
                                    Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: [
                                                accent.withAlpha(55),
                                                accent.withAlpha(20),
                                                Colors.transparent,
                                              ],
                                              stops: const [0.0, 0.5, 1.0],
                                            ),
                                          ),
                                        )
                                        .animate(delay: 150.ms)
                                        .fadeIn(duration: 600.ms)
                                        .scale(
                                          begin: const Offset(0.4, 0.4),
                                          duration: 800.ms,
                                          curve: Curves.easeOut,
                                        ),
                              ),
                              Text(
                                    '$newLevel',
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 96),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1,
                                    ),
                                  )
                                  .animate(delay: 150.ms)
                                  .scale(
                                    begin: const Offset(0.5, 0.5),
                                    duration: 600.ms,
                                    curve: Curves.elasticOut,
                                  )
                                  .fadeIn(duration: 300.ms),
                            ],
                          ),

                          SizedBox(height: Responsive.height(context, 10)),

                          Text(
                                r.name,
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 22),
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withAlpha(220),
                                ),
                              )
                              .animate(delay: 300.ms)
                              .fadeIn(duration: 400.ms)
                              .slideY(
                                begin: 0.15,
                                duration: 400.ms,
                                curve: Curves.easeOut,
                              ),

                          SizedBox(height: Responsive.height(context, 4)),

                          Text(
                            r.desc,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 12),
                              color: dim,
                            ),
                          ).animate(delay: 360.ms).fadeIn(duration: 400.ms),

                          SizedBox(height: Responsive.height(context, 20)),

                          if (widget.xpNeeded > 0)
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${widget.currentXp} XP',
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(context, 11),
                                        fontWeight: FontWeight.w600,
                                        color: accent,
                                      ),
                                    ),
                                    Text(
                                      '${widget.xpNeeded} XP to Level ${newLevel + 1}',
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(context, 11),
                                        fontWeight: FontWeight.w500,
                                        color: dim,
                                      ),
                                    ),
                                  ],
                                ).animate(delay: 420.ms).fadeIn(duration: 300.ms),
                                SizedBox(height: Responsive.height(context, 8)),
                                ClipRRect(
                                      borderRadius: BorderRadius.circular(99),
                                      child: Container(
                                        height: Responsive.height(context, 6),
                                        color: Colors.white.withAlpha(18),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: _AnimatedXpBar(
                                            progress: widget.xpProgress,
                                            accent: accent,
                                          ),
                                        ),
                                      ),
                                    )
                                    .animate(delay: 420.ms)
                                    .fadeIn(duration: 300.ms),
                              ],
                            ),

                          if (widget.stats.isNotEmpty) ...[
                            SizedBox(height: Responsive.height(context, 20)),
                            Container(
                              height: 1,
                              color: Colors.white.withAlpha(15),
                            ).animate(delay: 550.ms).fadeIn(duration: 300.ms),
                            SizedBox(height: Responsive.height(context, 14)),
                            Text(
                              'YOUR ACCOMPLISHMENTS SO FAR',
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 10),
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withAlpha(60),
                                letterSpacing: 3,
                              ),
                            ).animate(delay: 580.ms).fadeIn(duration: 300.ms),
                            SizedBox(height: Responsive.height(context, 10)),
                            Wrap(
                              spacing: Responsive.width(context, 12),
                              runSpacing: Responsive.height(context, 10),
                              alignment: WrapAlignment.center,
                              children: [
                                for (int i = 0; i < widget.stats.length; i++)
                                  Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: Responsive.width(
                                            context,
                                            12,
                                          ),
                                          vertical: Responsive.height(
                                            context,
                                            8,
                                          ),
                                        ),
                                        decoration: BoxDecoration(
                                          color: accent.withAlpha(12),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: accent.withAlpha(40),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            HugeIcon(
                                              icon: widget.stats[i].icon,
                                              color: dim,
                                              size: Responsive.scale(
                                                context,
                                                13,
                                              ),
                                            ),
                                            SizedBox(
                                              width: Responsive.width(
                                                context,
                                                6,
                                              ),
                                            ),
                                            Text(
                                              widget.stats[i].value,
                                              style: GoogleFonts.manrope(
                                                fontSize: Responsive.font(
                                                  context,
                                                  13,
                                                ),
                                                fontWeight: FontWeight.w700,
                                                color: accent,
                                              ),
                                            ),
                                            SizedBox(
                                              width: Responsive.width(
                                                context,
                                                4,
                                              ),
                                            ),
                                            Text(
                                              widget.stats[i].label,
                                              style: GoogleFonts.manrope(
                                                fontSize: Responsive.font(
                                                  context,
                                                  11,
                                                ),
                                                color: dim,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .animate(
                                        delay: Duration(
                                          milliseconds: 600 + i * 60,
                                        ),
                                      )
                                      .fadeIn(duration: 300.ms)
                                      .slideY(
                                        begin: 0.1,
                                        duration: 300.ms,
                                        curve: Curves.easeOut,
                                      ),
                              ],
                            ),
                          ],

                          SizedBox(height: Responsive.height(context, 28)),

                          Text(
                                'Tap anywhere to continue',
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 12),
                                  color: Colors.white.withAlpha(60),
                                  letterSpacing: 1.5,
                                ),
                              )
                              .animate(delay: 900.ms)
                              .fadeIn(duration: 600.ms)
                              .then()
                              .shimmer(
                                duration: 1800.ms,
                                delay: 200.ms,
                                color: Colors.white.withAlpha(40),
                              ),
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
