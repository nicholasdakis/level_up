import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../globals.dart';
import '../../utility/responsive.dart';
import '/providers/user_data_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;
import '../premium_sheet.dart' show showPremiumSheet;

// Stat tile used in the summary row across analytics screens
Widget analyticsStatTile(
  BuildContext context,
  Color appColor, {
  required IconData icon,
  required String label,
  required String value,
  Color? valueColor,
}) {
  final accent = onTheme(appColor);
  return Expanded(
    child: frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 10),
        vertical: Responsive.height(context, 14),
      ),
      child: Column(
        children: [
          HugeIcon(
            icon: icon,
            color: accent,
            size: Responsive.font(context, 18),
          ),
          SizedBox(height: Responsive.height(context, 6)),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 13),
              fontWeight: FontWeight.w800,
              color: valueColor ?? accent,
              height: 1.1,
            ),
          ),
          SizedBox(height: Responsive.height(context, 6)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 8),
                vertical: Responsive.height(context, 3),
              ),
              decoration: BoxDecoration(
                color: accent.withAlpha(40),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 10),
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Returns true if the premium gate was shown (caller should return early)
// Used in _applyChip across analytics screens to block chips 2+ for free users
bool showAnalyticsPremiumGate(
  BuildContext context,
  WidgetRef ref,
  Color appColor,
  bool isPremium,
  int index,
) {
  if (isPremium || index < 2) return false;
  _showAnalyticsProDialog(context, ref, appColor);
  return true;
}

// Callback for onLockedTap on shimmer chips, shows the pro feature dialog
VoidCallback analyticsLockedChipTap(
  BuildContext context,
  WidgetRef ref,
  Color appColor,
) =>
    () => _showAnalyticsProDialog(context, ref, appColor);

void _showAnalyticsProDialog(
  BuildContext context,
  WidgetRef ref,
  Color appColor,
) {
  showProFeatureDialog(
    context,
    feature: 'Full Progress History',
    appColor: appColor,
    onLearnMore: () {
      logAnalyticsEvent('premium_sheet_opened_from_learn_more');
      showPremiumSheet(context, ref);
    },
  );
}

// Calendar range picker card + hint text, shared across analytics screens
// onRangeSelected fires when both dates are picked; rangeLabel appears in the hint text
// collapses to show selected range info once a range is picked, same card throughout
class RangePickerCard extends ConsumerStatefulWidget {
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final bool rangeSelected;
  final DateTime calendarFocused;
  final String rangeLabel;
  final void Function(DateTime? start, DateTime? end, DateTime focused)
  onRangeSelected;
  final void Function(DateTime focused) onPageChanged;
  final VoidCallback onClearRange;
  final DateTime? firstDay;

  const RangePickerCard({
    super.key,
    required this.rangeStart,
    required this.rangeEnd,
    required this.rangeSelected,
    required this.calendarFocused,
    required this.rangeLabel,
    required this.onRangeSelected,
    required this.onPageChanged,
    required this.onClearRange,
    this.firstDay,
  });

  @override
  ConsumerState<RangePickerCard> createState() => _RangePickerCardState();
}

class _RangePickerCardState extends ConsumerState<RangePickerCard> {
  late bool _collapsed = widget.rangeSelected;

  @override
  void didUpdateWidget(RangePickerCard old) {
    super.didUpdateWidget(old);
    // auto-collapse when a range is picked, re-expand when cleared
    if (widget.rangeSelected && !old.rangeSelected) {
      setState(() => _collapsed = true);
    } else if (!widget.rangeSelected && old.rangeSelected) {
      setState(() => _collapsed = false);
    }
  }

  String _formatRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '';
    return '${formatDateShort(start)} – ${formatDateShort(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final appColor = ref.watch(
      userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
    );
    final accent = onTheme(appColor);

    return GestureDetector(
      onTap: _collapsed
          ? () {
              setState(() => _collapsed = false);
              widget.onClearRange();
            }
          : null,
      child: frostedGlassCard(
        context,
        color: appColor,
        padding: EdgeInsets.all(Responsive.scale(context, 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // collapsed header, always visible
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Current Range",
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 11),
                        fontWeight: FontWeight.w500,
                        color: onTheme(appColor).withAlpha(140),
                      ),
                    ),
                    if (_collapsed) ...[
                      SizedBox(height: Responsive.height(context, 2)),
                      Text(
                        _formatRange(widget.rangeStart, widget.rangeEnd),
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 16),
                          fontWeight: FontWeight.w700,
                          color: onTheme(appColor),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_collapsed)
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCalendar03,
                        color: accent,
                        size: Responsive.font(context, 15),
                      ),
                      SizedBox(width: Responsive.width(context, 5)),
                      Text(
                        "Tap to change",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 13),
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            // calendar and hint, animated in/out
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _collapsed
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          SizedBox(height: Responsive.height(context, 8)),
                          TableCalendar(
                            firstDay: widget.firstDay ?? DateTime(2020),
                            lastDay: DateTime.now(),
                            focusedDay: widget.calendarFocused,
                            rangeStartDay: widget.rangeStart,
                            rangeEndDay: widget.rangeSelected
                                ? widget.rangeEnd
                                : null,
                            rangeSelectionMode: RangeSelectionMode.toggledOn,
                            // AvailableGestures.none disables the built-in gesture recognizers so mouse clicks register correctly
                            availableGestures: AvailableGestures.none,
                            onRangeSelected: widget.onRangeSelected,
                            onPageChanged: widget.onPageChanged,
                            calendarStyle: CalendarStyle(
                              outsideDaysVisible: false,
                              todayDecoration: const BoxDecoration(),
                              rangeStartDecoration: BoxDecoration(
                                color: appColor,
                                shape: BoxShape.circle,
                              ),
                              rangeEndDecoration: BoxDecoration(
                                color: appColor,
                                shape: BoxShape.circle,
                              ),
                              withinRangeDecoration: const BoxDecoration(
                                color: Colors.transparent,
                              ),
                              rangeHighlightColor: Colors.white.withAlpha(25),
                              defaultTextStyle: GoogleFonts.manrope(
                                color: onTheme(appColor),
                                fontSize: Responsive.font(context, 13),
                              ),
                              weekendTextStyle: GoogleFonts.manrope(
                                color: onTheme(appColor),
                                fontSize: Responsive.font(context, 13),
                              ),
                              todayTextStyle: GoogleFonts.manrope(
                                color: onTheme(appColor),
                                fontSize: Responsive.font(context, 13),
                              ),
                              rangeStartTextStyle: GoogleFonts.manrope(
                                color: onTheme(appColor),
                                fontSize: Responsive.font(context, 13),
                                fontWeight: FontWeight.w700,
                              ),
                              rangeEndTextStyle: GoogleFonts.manrope(
                                color: onTheme(appColor),
                                fontSize: Responsive.font(context, 13),
                                fontWeight: FontWeight.w700,
                              ),
                              withinRangeTextStyle: GoogleFonts.manrope(
                                color: onTheme(appColor),
                                fontSize: Responsive.font(context, 13),
                              ),
                              outsideTextStyle: GoogleFonts.manrope(
                                color: onTheme(appColor).withAlpha(100),
                                fontSize: Responsive.font(context, 13),
                              ),
                              disabledTextStyle: GoogleFonts.manrope(
                                color: onTheme(appColor).withAlpha(100),
                                fontSize: Responsive.font(context, 13),
                              ),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: GoogleFonts.manrope(
                                color: onTheme(appColor),
                                fontSize: Responsive.font(context, 14),
                                fontWeight: FontWeight.w700,
                              ),
                              leftChevronIcon: HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowLeft01,
                                color: onTheme(appColor),
                                size: Responsive.font(context, 22),
                              ),
                              rightChevronIcon: HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight01,
                                color: onTheme(appColor),
                                size: Responsive.font(context, 22),
                              ),
                            ),
                            daysOfWeekStyle: DaysOfWeekStyle(
                              weekdayStyle: GoogleFonts.manrope(
                                color: onTheme(appColor).withAlpha(140),
                                fontSize: Responsive.font(context, 12),
                                fontWeight: FontWeight.w600,
                              ),
                              weekendStyle: GoogleFonts.manrope(
                                color: onTheme(appColor).withAlpha(140),
                                fontSize: Responsive.font(context, 12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!widget.rangeSelected) ...[
                            Divider(
                              color: onTheme(appColor).withAlpha(50),
                              thickness: 1,
                              height: Responsive.height(context, 32),
                            ),
                            Text(
                              "Pick a start date, then an end date to view your ${widget.rangeLabel}",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 13),
                                fontWeight: FontWeight.w500,
                                color: onTheme(appColor).withAlpha(140),
                              ),
                            ),
                            SizedBox(height: Responsive.height(context, 8)),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

// Converts a "YYYY-MM-DD" key to a short display label like "Jun 3"
String formatDateKeyShort(String key) {
  final parts = key.split('-');
  return '${_shortMonths[int.parse(parts[1]) - 1]} ${int.parse(parts[2])}';
}

// Converts a DateTime to a short display label like "Jun 3"
String formatDateShort(DateTime date) =>
    '${_shortMonths[date.month - 1]} ${date.day}';

// Quick-select range chips shared across analytics screens
// labels is the list of chip labels, selectedIndex is the active one, onTap fires with the tapped index
Widget buildRangeChips(
  BuildContext context,
  List<String> labels,
  int selectedIndex,
  void Function(int) onTap, {
  required Color appColor,
  List<int> shimmerIndices = const [],
  VoidCallback? onLockedTap,
}) {
  final accent = onTheme(appColor);

  Widget normalChip(int i) => GestureDetector(
    onTap: () => onTap(i),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 14),
        vertical: Responsive.height(context, 7),
      ),
      decoration: BoxDecoration(
        color: selectedIndex == i ? accent.withAlpha(40) : accent.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selectedIndex == i
              ? accent.withAlpha(120)
              : accent.withAlpha(20),
          width: 1.5,
        ),
      ),
      child: Text(
        labels[i],
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 13),
          fontWeight: selectedIndex == i ? FontWeight.w700 : FontWeight.w500,
          color: selectedIndex == i ? accent : onTheme(appColor),
        ),
      ),
    ),
  );

  Widget shimmerChip(int i) =>
      _ShimmerChip(label: labels[i], appColor: appColor, onTap: onLockedTap);

  return Row(
    children: [
      for (int i = 0; i < labels.length; i++) ...[
        Expanded(
          child: shimmerIndices.contains(i) ? shimmerChip(i) : normalChip(i),
        ),
        if (i < labels.length - 1)
          SizedBox(width: Responsive.width(context, 8)),
      ],
    ],
  );
}

Widget legendDot(BuildContext context, String label, Color color, Color dim) {
  return Row(
    children: [
      Container(
        width: Responsive.scale(context, 8),
        height: Responsive.scale(context, 8),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      SizedBox(width: Responsive.width(context, 4)),
      Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 11),
          color: dim,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _ShimmerChip extends StatefulWidget {
  final String label;
  final Color appColor;
  final VoidCallback? onTap;
  const _ShimmerChip({required this.label, required this.appColor, this.onTap});

  @override
  State<_ShimmerChip> createState() => _ShimmerChipState();
}

class _ShimmerChipState extends State<_ShimmerChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dim = onTheme(widget.appColor);
    final mid = onTheme(widget.appColor);
    final accent = onTheme(widget.appColor);
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          final pos = _ctrl.value;
          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.width(context, 14),
              vertical: Responsive.height(context, 7),
            ),
            decoration: BoxDecoration(
              color: accent.withAlpha(10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withAlpha(20), width: 1.5),
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(-1.5 + pos * 3.5, 0),
                end: Alignment(-0.5 + pos * 3.5, 0),
                colors: [dim, mid, Colors.white.withAlpha(220), mid, dim],
                stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              ).createShader(bounds),
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 13),
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
