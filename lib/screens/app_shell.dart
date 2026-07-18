import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'floating_nav_bar.dart' show FloatingNavBar, kTabExplore;
import 'premium_sheet.dart' show showPremiumSheet;
import 'workout_mini_bar.dart';
import '../utility/responsive.dart';
import '../globals.dart';
import '../models/workout_session.dart';
import '/providers/user_data_provider.dart';
import '/providers/workout_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  String _elapsedLabel(Duration elapsed) {
    final h = elapsed.inHours;
    final m = elapsed.inMinutes % 60;
    final sec = elapsed.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColor = ref.watch(
      userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
    );
    // only rebuilds when the session itself changes (start/clear), not every tick
    final session = ref.watch(
      workoutProvider.select((s) => s.value?.activeSession),
    );
    // only rebuilds every second while a session is active
    final elapsed = ref.watch(
      workoutProvider.select((s) => s.value?.activeSession?.elapsed),
    );

    final selectedIndex = navigationShell.currentIndex;
    final showMiniBar = session != null;

    final navBarBottomPad = Responsive.padding(context, 16);
    final navBarHeight = Responsive.scale(context, 72);
    final systemBottomPad = MediaQuery.of(context).padding.bottom;
    final miniBarBottom =
        navBarBottomPad +
        navBarHeight +
        Responsive.height(context, 10) +
        systemBottomPad;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final navHPad = Responsive.centeredHorizontalPadding(context, 24);
    final navBarWidth = screenWidth - navHPad * 2;
    // cap the mini bar so it stays visibly shorter than the nav bar on all screen sizes
    final miniBarMaxWidth = Responsive.scale(context, 300);
    // left offset that centers the bar within the nav bar bounds
    final miniBarLeft =
        navHPad +
        ((navBarWidth - miniBarMaxWidth) / 2).clamp(0, double.infinity);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tab content
          navigationShell,

          // Floating nav bar, hidden on Explore since it covers the map
          if (selectedIndex != kTabExplore)
            Positioned(
              bottom: navBarBottomPad,
              left: Responsive.centeredHorizontalPadding(context, 24),
              right: Responsive.centeredHorizontalPadding(context, 24),
              child: FloatingNavBar(
                selectedIndex: selectedIndex,
                onTap: (index) {
                  if (onboardingHintNotifier.value != null) return;
                  navigationShell.goBranch(
                    index,
                    initialLocation: index == selectedIndex,
                  );
                },
              ),
            ),

          // Mini workout bar / collapsed dot, shown above nav bar while a session is active
          if (showMiniBar && selectedIndex != kTabExplore)
            _MiniBarWrapper(
              session: session,
              elapsedLabel: elapsed != null ? _elapsedLabel(elapsed) : '00:00',
              appColor: appColor,
              miniBarBottom: miniBarBottom,
              miniBarLeft: miniBarLeft,
              miniBarMaxWidth: miniBarMaxWidth,
            ),

          // Premium theme preview countdown bubble, hidden on Explore tab
          if (selectedIndex != kTabExplore) const _ThemePreviewCountdown(),
        ],
      ),
    );
  }
}

// Separate StatefulWidget just for the collapsed/expanded toggle so only this rebuilds
class _MiniBarWrapper extends StatefulWidget {
  final WorkoutSession session;
  final String elapsedLabel;
  final Color appColor;
  final double miniBarBottom;
  final double miniBarLeft;
  final double miniBarMaxWidth;

  const _MiniBarWrapper({
    required this.session,
    required this.elapsedLabel,
    required this.appColor,
    required this.miniBarBottom,
    required this.miniBarLeft,
    required this.miniBarMaxWidth,
  });

  @override
  State<_MiniBarWrapper> createState() => _MiniBarWrapperState();
}

class _MiniBarWrapperState extends State<_MiniBarWrapper> {
  bool _miniCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
      bottom: widget.miniBarBottom,
      left: widget.miniBarLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.miniBarMaxWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Responsive.scale(context, 21)),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.centerLeft,
            child: _miniCollapsed
                ? CollapsedWorkoutDot(
                    appColor: widget.appColor,
                    onTap: () => setState(() => _miniCollapsed = false),
                  )
                : MiniWorkoutBar(
                    session: widget.session,
                    elapsedLabel: widget.elapsedLabel,
                    appColor: widget.appColor,
                    onTap: () => context.push('/workout/active'),
                    onCollapse: () => setState(() => _miniCollapsed = true),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewCountdown extends ConsumerStatefulWidget {
  const _ThemePreviewCountdown();

  @override
  ConsumerState<_ThemePreviewCountdown> createState() =>
      _ThemePreviewCountdownState();
}

class _ThemePreviewCountdownState
    extends ConsumerState<_ThemePreviewCountdown> {
  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    premiumPreviewNotifier.addListener(_onPreviewChanged);
    _syncFromNotifier();
  }

  @override
  void dispose() {
    premiumPreviewNotifier.removeListener(_onPreviewChanged);
    _ticker?.cancel();
    super.dispose();
  }

  void _onPreviewChanged() => _syncFromNotifier();

  void _syncFromNotifier() {
    final preview = premiumPreviewNotifier.value;
    _ticker?.cancel();
    if (preview == null) {
      if (mounted) setState(() => _secondsLeft = 0);
      return;
    }
    final remaining = preview.expiresAt.difference(DateTime.now()).inSeconds;
    if (mounted) setState(() => _secondsLeft = remaining.clamp(0, 999));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final p = premiumPreviewNotifier.value;
      if (p == null) {
        _ticker?.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
        return;
      }
      final secs = p.expiresAt.difference(DateTime.now()).inSeconds;
      if (secs <= 0) {
        _ticker?.cancel();
        ref
            .read(userDataProvider.notifier)
            .patch((u) => u.copyWith(appColor: p.originalColor));
        premiumPreviewNotifier.value = null;
      } else {
        if (mounted) setState(() => _secondsLeft = secs);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = premiumPreviewNotifier.value;
    if (preview == null || _secondsLeft <= 0) return const SizedBox.shrink();

    final appColor = ref.watch(
      userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
    );
    final topPad =
        MediaQuery.of(context).padding.top + Responsive.height(context, 12);

    final card = cardColors(appColor);

    return Positioned(
      top: topPad,
      left: Responsive.centeredHorizontalPadding(context, 16),
      right: Responsive.centeredHorizontalPadding(context, 16),
      child: GestureDetector(
        onTap: () => showPremiumSheet(context, ref),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Responsive.scale(context, 18)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 16),
                vertical: Responsive.height(context, 16),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: card.gradient),
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 18),
                ),
                border: Border.all(color: card.border, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.palette_outlined,
                    color: card.onCard,
                    size: Responsive.scale(context, 22),
                  ),
                  SizedBox(width: Responsive.width(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Theme color preview',
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 15),
                            color: card.onCard,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 2)),
                        Text(
                          'Resets in ${_secondsLeft}s. Tap to keep this color.',
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 12),
                            color: card.onCard,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: Responsive.width(context, 10)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.width(context, 14),
                      vertical: Responsive.height(context, 10),
                    ),
                    decoration: BoxDecoration(
                      color: appColor.withAlpha(120),
                      borderRadius: BorderRadius.circular(
                        Responsive.scale(context, 20),
                      ),
                      border: Border.all(
                        color: card.onCard.withAlpha(60),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_new,
                          color: card.onCard,
                          size: Responsive.scale(context, 13),
                        ),
                        SizedBox(width: Responsive.width(context, 4)),
                        Text(
                          'Keep it',
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 13),
                            color: card.onCard,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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
