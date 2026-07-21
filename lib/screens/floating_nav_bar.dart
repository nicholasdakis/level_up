import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../globals.dart';
import '../utility/responsive.dart';
import '../providers/user_data_provider.dart';
import '../services/user_data_manager.dart' show defaultAppColor;

// Tab index constants
const kTabHome = 0;
const kTabWorkout = 1;
const kTabFood = 2;
const kTabProgress = 3;
const kTabSocial = 4;
const kTabExplore = 5;

// Routes matching each tab index, order must match _navIcons and _navLabels
const _navRoutes = [
  '/',
  '/workout',
  '/food-logging',
  '/progression',
  '/social',
  '/explore',
];

// icons for each tab
const _navIcons = [
  HugeIcons.strokeRoundedHome09,
  HugeIcons.strokeRoundedDumbbell01,
  HugeIcons.strokeRoundedPencil,
  HugeIcons.strokeRoundedMedal02,
  HugeIcons.strokeRoundedUserGroup,
  HugeIcons.strokeRoundedLocation01,
];

// Labels shown below each icon, active label is slightly larger and bolder
const _navLabels = ['Home', 'Workout', 'Food', 'Progress', 'Social', 'Explore'];

// Floating frosted glass bottom navigation bar with 5 persistent tabs
class FloatingNavBar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  // Maps a router location string to a tab index, iterates in reverse so
  // nested routes like /food-logging/log correctly resolve to the food tab
  static int indexForLocation(String location) {
    for (int i = _navRoutes.length - 1; i >= 0; i--) {
      if (location.startsWith(_navRoutes[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColor = ref.watch(
      userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
    );
    return SafeArea(
      // SafeArea prevents the bar from overlapping the home indicator on iOS
      child: Center(
        child: ConstrainedBox(
          // Cap the width so the bar doesn't stretch too wide on tablets/desktop
          constraints: BoxConstraints(maxWidth: Responsive.scale(context, 360)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: frostedGlassCard(
                context,
                color: appColor,
                baseRadius: 30,
                // Navbar fill and border adapt to background lightness so it always pops
                backgroundColor: appColor.computeLuminance() < 0.18
                    ? Colors.white.withAlpha(18)
                    : Colors.white.withAlpha(50),
                border: appColor.computeLuminance() < 0.18
                    ? Border.all(
                        color: Colors.white.withAlpha(35),
                        width: Responsive.width(context, 1.5),
                      )
                    : Border.all(
                        color: Colors.white.withAlpha(90),
                        width: Responsive.width(context, 1.5),
                      ),
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.padding(context, 8),
                  vertical: Responsive.padding(context, 10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (int i = 0; i < _navIcons.length; i++)
                      _NavItem(
                        icon: _navIcons[i],
                        label: _navLabels[i],
                        isActive: selectedIndex == i,
                        appColor: appColor,
                        onTap: () => onTap(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// A single tab item in the nav bar, icon grows and label brightens when active
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color appColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.appColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = appColor.computeLuminance() >= 0.18;
    final activeColor = isLight
        ? darkenColor(appColor, 0.35)
        : onTheme(appColor);
    final inactiveColor = onTheme(appColor).withAlpha(isLight ? 120 : 150);
    final inactiveLabelColor = onTheme(appColor).withAlpha(isLight ? 100 : 120);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // makes the full padding area tappable
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.padding(context, 10),
          vertical: Responsive.padding(context, 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon grows when active to emphasize selected tab
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              child: HugeIcon(
                icon: icon,
                color: isActive ? activeColor : inactiveColor,
                size: Responsive.scale(context, isActive ? 28 : 23),
              ),
            ),
            SizedBox(height: Responsive.scale(context, 3)),
            // Label animates color and weight, invisible on inactive tabs
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isActive ? activeColor : inactiveLabelColor,
                fontSize: isActive
                    ? Responsive.font(context, 11)
                    : Responsive.font(context, 10),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'Manrope',
              ),
              child: Text(label),
            ),
            SizedBox(height: Responsive.scale(context, 3)),
            // Accent dot under active tab
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isActive ? Responsive.scale(context, 16) : 0,
              height: Responsive.scale(context, 3),
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
