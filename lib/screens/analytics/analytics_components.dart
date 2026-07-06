import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../globals.dart';
import '../../utility/responsive.dart';
import '/providers/user_data_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;

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
    final appColor =
        ref.watch(userDataProvider).value?.appColor ?? defaultAppColor;
    final accent = lightenColor(appColor, 0.45);

    return GestureDetector(
      onTap: _collapsed
          ? () {
              setState(() => _collapsed = false);
              widget.onClearRange();
            }
          : null,
      child: frostedGlassCard(
        context,
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
                        color: Colors.white38,
                      ),
                    ),
                    if (_collapsed) ...[
                      SizedBox(height: Responsive.height(context, 2)),
                      Text(
                        _formatRange(widget.rangeStart, widget.rangeEnd),
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 16),
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
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
                            firstDay: DateTime(2020),
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
                                color: Colors.white70,
                                fontSize: Responsive.font(context, 13),
                              ),
                              weekendTextStyle: GoogleFonts.manrope(
                                color: Colors.white70,
                                fontSize: Responsive.font(context, 13),
                              ),
                              todayTextStyle: GoogleFonts.manrope(
                                color: Colors.white70,
                                fontSize: Responsive.font(context, 13),
                              ),
                              rangeStartTextStyle: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: Responsive.font(context, 13),
                                fontWeight: FontWeight.w700,
                              ),
                              rangeEndTextStyle: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: Responsive.font(context, 13),
                                fontWeight: FontWeight.w700,
                              ),
                              withinRangeTextStyle: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: Responsive.font(context, 13),
                              ),
                              outsideTextStyle: GoogleFonts.manrope(
                                color: Colors.white24,
                                fontSize: Responsive.font(context, 13),
                              ),
                              disabledTextStyle: GoogleFonts.manrope(
                                color: Colors.white24,
                                fontSize: Responsive.font(context, 13),
                              ),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: Responsive.font(context, 14),
                                fontWeight: FontWeight.w700,
                              ),
                              leftChevronIcon: HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowLeft01,
                                color: Colors.white70,
                                size: Responsive.font(context, 22),
                              ),
                              rightChevronIcon: HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight01,
                                color: Colors.white70,
                                size: Responsive.font(context, 22),
                              ),
                            ),
                            daysOfWeekStyle: DaysOfWeekStyle(
                              weekdayStyle: GoogleFonts.manrope(
                                color: Colors.white38,
                                fontSize: Responsive.font(context, 12),
                                fontWeight: FontWeight.w600,
                              ),
                              weekendStyle: GoogleFonts.manrope(
                                color: Colors.white38,
                                fontSize: Responsive.font(context, 12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!widget.rangeSelected) ...[
                            Divider(
                              color: Colors.white.withAlpha(20),
                              thickness: 1,
                              height: Responsive.height(context, 32),
                            ),
                            Text(
                              "Pick a start date, then an end date to view your ${widget.rangeLabel}",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 13),
                                fontWeight: FontWeight.w500,
                                color: Colors.white38,
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
  void Function(int) onTap,
) {
  final accent = lightenColor(appColor, 0.45);
  Widget chip(int i) => GestureDetector(
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
          width: 1,
        ),
      ),
      child: Text(
        labels[i],
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 13),
          fontWeight: selectedIndex == i ? FontWeight.w700 : FontWeight.w500,
          color: selectedIndex == i ? accent : lightenColor(appColor, 0.3),
        ),
      ),
    ),
  );

  return Row(
    children: [
      for (int i = 0; i < labels.length; i++) ...[
        Expanded(child: chip(i)),
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
