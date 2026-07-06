import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../globals.dart';
import '../../utility/responsive.dart';
import '../../utility/unit_converter.dart';
import 'analytics_components.dart';

class WaterAnalyticsScreen extends ConsumerStatefulWidget {
  const WaterAnalyticsScreen({super.key});

  @override
  ConsumerState<WaterAnalyticsScreen> createState() =>
      _WaterAnalyticsScreenState();
}

class _WaterAnalyticsScreenState extends ConsumerState<WaterAnalyticsScreen> {
  Color get appColor =>
      ref.watch(userDataProvider).value?.appColor ?? defaultAppColor;

  // quick-select chip index: 0=1W, 1=2W, 2=1M, 3=3M, 4=All, 5=Custom
  int _chipIndex = 0;

  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _rangeSelected = false;
  DateTime _calendarFocused = DateTime.now();
  int _animationKey = 0;

  String? _deletingKey;
  final _addController = TextEditingController();
  DateTime _addDate = DateTime.now();
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/water/analytics',
      screenClass: 'WaterAnalyticsScreen',
    );
    _applyChip(0);
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  String _dateKeyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _deleteEntry(String dateKey) async {
    await userManager.updateWaterLog(dateKey, []);
    if (mounted) {
      setState(() => _deletingKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _addEntry() async {
    final isImperial = UnitConverter.isImperial;
    final raw = double.tryParse(_addController.text.trim());
    if (raw == null) return;
    // convert oz to ml if imperial, otherwise use as-is
    final ml = isImperial ? UnitConverter.ozToMl(raw).round() : raw.round();
    final key = _dateKeyFor(_addDate);
    final existing = List<int>.from(
      ref.read(userDataProvider).value?.waterEntriesByDate[key] ?? [],
    );
    setState(() => _isAdding = true);
    await userManager.updateWaterLog(key, [...existing, ml]);
    if (mounted) {
      setState(() {
        _isAdding = false;
        _addController.clear();
      });
    }
  }

  // Sets the chart range based on the selected quick-select chip
  void _applyChip(int index) {
    final now = DateTime.now();
    setState(() {
      _chipIndex = index;
      _deletingKey = null;
      _animationKey++;
      switch (index) {
        case 0:
          _rangeStart = now.subtract(const Duration(days: 6));
          _rangeEnd = now;
          _rangeSelected = true;
        case 1:
          _rangeStart = now.subtract(const Duration(days: 13));
          _rangeEnd = now;
          _rangeSelected = true;
        case 2:
          _rangeStart = DateTime(now.year, now.month - 1, now.day);
          _rangeEnd = now;
          _rangeSelected = true;
        case 3:
          _rangeStart = DateTime(now.year, now.month - 3, now.day);
          _rangeEnd = now;
          _rangeSelected = true;
        case 4:
          final entries = _sortedEntries();
          _rangeStart = entries.isNotEmpty
              ? DateTime.parse(entries.first.key)
              : now.subtract(const Duration(days: 6));
          _rangeEnd = now;
          _rangeSelected = true;
        case 5:
          _rangeStart = null;
          _rangeEnd = null;
          _rangeSelected = false;
      }
    });
  }

  // Returns all water entries as (date, totalMl) sorted chronologically oldest-first
  List<MapEntry<String, int>> _sortedEntries() {
    final byDate = ref.watch(userDataProvider).value?.waterEntriesByDate ?? {};
    final entries = byDate.entries.map((e) {
      final total = e.value.fold(0, (s, v) => s + v);
      return MapEntry(e.key, total);
    }).toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  // Filters sorted entries to only those within the selected date range
  List<MapEntry<String, int>> _entriesInRange() {
    if (_rangeStart == null || _rangeEnd == null) return [];
    final startKey = _rangeStart!.toIso8601String().substring(0, 10);
    final endKey = _rangeEnd!.toIso8601String().substring(0, 10);
    return _sortedEntries()
        .where(
          (e) => e.key.compareTo(startKey) >= 0 && e.key.compareTo(endKey) <= 0,
        )
        .toList();
  }

  Widget _buildChart(
    BuildContext context,
    List<MapEntry<String, int>> entries,
  ) {
    final isImperial = UnitConverter.isImperial;
    final accent = lightenColor(appColor, 0.45);
    final dimAccent = lightenColor(appColor, 0.3);
    final goalMl = ref.watch(userDataProvider).value?.waterMlGoal ?? 0;

    if (entries.isEmpty) {
      return frostedGlassCard(
        context,
        padding: EdgeInsets.all(Responsive.scale(context, 20)),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: Responsive.height(context, 32),
            ),
            child: Text(
              _rangeSelected
                  ? "No water logged in this range"
                  : "Pick a range to view your water trend",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 14),
                color: dimAccent,
              ),
            ),
          ),
        ),
      );
    }

    // convert ml to display unit for charting
    double toDisplay(int ml) => isImperial
        ? double.parse(UnitConverter.displayWater(ml, imperial: true))
        : ml.toDouble();

    final spots = <FlSpot>[
      for (int i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), toDisplay(entries[i].value)),
    ];

    final allY = spots.map((s) => s.y).toList();
    if (goalMl > 0) allY.add(toDisplay(goalMl));
    final minY = allY.reduce((a, b) => a < b ? a : b);
    final maxY = allY.reduce((a, b) => a > b ? a : b);
    final yPad = (maxY - minY) == 0 ? 100.0 : (maxY - minY) * 0.2;

    final goalLine = goalMl > 0
        ? [
            HorizontalLine(
              y: toDisplay(goalMl),
              color: accent.withAlpha(160),
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                labelResolver: (_) =>
                    '${isImperial ? UnitConverter.displayWater(goalMl, imperial: true) : goalMl} ${isImperial ? 'oz' : 'ml'} goal',
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 11),
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]
        : <HorizontalLine>[];

    // hide bottom labels when there are too many entries to avoid overlap
    final showLabels = entries.length <= 10;
    // show every other label when there are 6-10 entries
    final labelInterval = entries.length <= 5 ? 1.0 : 2.0;

    return frostedGlassCard(
      context,
      padding: EdgeInsets.all(Responsive.scale(context, 16)),
      child: SizedBox(
        height: Responsive.height(context, 220),
        child: LineChart(
          LineChartData(
            minY: (minY - yPad).clamp(0, double.infinity),
            maxY: maxY + yPad,
            extraLinesData: ExtraLinesData(horizontalLines: goalLine),
            clipData: const FlClipData.none(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) =>
                    darkenColor(appColor, 0.1).withAlpha(220),
                getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                  final entry = entries[s.spotIndex];
                  return LineTooltipItem(
                    '${formatDateKeyShort(entry.key)}\n',
                    GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 11),
                      color: dimAccent,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: isImperial
                            ? '${UnitConverter.displayWater(entry.value, imperial: true)} oz'
                            : '${entry.value} ml',
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 13),
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: Responsive.width(context, 44),
                  getTitlesWidget: (val, info) {
                    if (val == info.min || val == info.max) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: info,
                      child: Text(
                        isImperial ? '${val.round()}oz' : '${val.round()}ml',
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 9),
                          color: dimAccent,
                        ),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: showLabels,
                  reservedSize: Responsive.height(context, 32),
                  interval: labelInterval,
                  getTitlesWidget: (val, info) {
                    final i = val.toInt();
                    if (i < 0 || i >= entries.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: info,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(info),
                      child: Text(
                        formatDateKeyShort(entries[i].key),
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 10),
                          color: dimAccent,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: accent,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                    radius: Responsive.scale(context, 4),
                    color: accent,
                    strokeWidth: 2,
                    strokeColor: darkenColor(appColor, 0.05).withAlpha(180),
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent.withAlpha(60), accent.withAlpha(0)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTiles(
    BuildContext context,
    List<MapEntry<String, int>> entries,
  ) {
    final isImperial = UnitConverter.isImperial;
    final unit = isImperial ? 'oz' : 'ml';
    final accent = lightenColor(appColor, 0.45);

    String fmt(int ml) => isImperial
        ? '${UnitConverter.displayWater(ml, imperial: true)} $unit'
        : '$ml $unit';

    // entries are sorted oldest-first
    final avg = entries.isNotEmpty
        ? (entries.fold(0, (total, entry) => total + entry.value) /
                  entries.length)
              .round()
        : 0;
    final best = entries.isNotEmpty
        ? entries.reduce((a, b) => a.value > b.value ? a : b).value
        : 0;

    Widget tile(IconData icon, String label, String value) => Expanded(
      child: frostedGlassCard(
        context,
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
                color: accent,
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

    return Row(
      children: [
        tile(
          HugeIcons.strokeRoundedDroplet,
          'Avg/day',
          entries.isEmpty ? '--' : fmt(avg),
        ),
        SizedBox(width: Responsive.width(context, 10)),
        tile(
          HugeIcons.strokeRoundedStar,
          'Best day',
          entries.isEmpty ? '--' : fmt(best),
        ),
      ],
    );
  }

  Widget _buildLogEntries(BuildContext context) {
    final isImperial = UnitConverter.isImperial;
    final unit = isImperial ? 'oz' : 'ml';
    final accent = lightenColor(appColor, 0.45);
    final dimAccent = lightenColor(appColor, 0.35);
    // all entries newest-first, each entry is the daily total
    final all = _sortedEntries().reversed.toList();

    return frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: Responsive.height(context, 10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 14),
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add water ($unit)',
                      hintStyle: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 13),
                        color: dimAccent,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: Responsive.height(context, 18),
                  color: dimAccent.withAlpha(60),
                  margin: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 10),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final picked = await showThemedDatePicker(
                      context: context,
                      initialDate: _addDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _addDate = picked);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.width(context, 10),
                      vertical: Responsive.height(context, 5),
                    ),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withAlpha(60), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar03,
                          color: accent,
                          size: Responsive.font(context, 12),
                        ),
                        SizedBox(width: Responsive.width(context, 4)),
                        Text(
                          formatDateKeyShort(_dateKeyFor(_addDate)),
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 12),
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: Responsive.width(context, 12)),
                GestureDetector(
                  onTap: _isAdding ? null : _addEntry,
                  child: _isAdding
                      ? SizedBox(
                          width: Responsive.font(context, 18),
                          height: Responsive.font(context, 18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent,
                          ),
                        )
                      : HugeIcon(
                          icon: HugeIcons.strokeRoundedPlusSign,
                          color: accent,
                          size: Responsive.font(context, 20),
                        ),
                ),
              ],
            ),
          ),
          if (all.isNotEmpty) ...[
            Divider(color: accent.withAlpha(30), height: 1, thickness: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: Responsive.height(context, 220),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < all.length; i++) ...[
                      if (i > 0)
                        Divider(
                          color: accent.withAlpha(15),
                          height: 1,
                          thickness: 1,
                        ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.height(context, 10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatDateKeyShort(all[i].key),
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 14),
                                fontWeight: FontWeight.w600,
                                color: dimAccent,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  isImperial
                                      ? '${UnitConverter.displayWater(all[i].value, imperial: true)} $unit'
                                      : '${all[i].value} $unit',
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 14),
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                                SizedBox(width: Responsive.width(context, 12)),
                                GestureDetector(
                                  onTap: () {
                                    if (_deletingKey == all[i].key) {
                                      _deleteEntry(all[i].key);
                                    } else {
                                      setState(() => _deletingKey = all[i].key);
                                    }
                                  },
                                  child: _deletingKey == all[i].key
                                      ? Text(
                                          "Confirm",
                                          style: GoogleFonts.manrope(
                                            fontSize: Responsive.font(
                                              context,
                                              13,
                                            ),
                                            color: lightenColor(appColor, 0.35),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : HugeIcon(
                                          icon: HugeIcons.strokeRoundedDelete02,
                                          color: lightenColor(appColor, 0.3),
                                          size: Responsive.font(context, 18),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColor =
        ref.watch(userDataProvider).value?.appColor ?? defaultAppColor;
    final entries = _entriesInRange();
    final hPad = Responsive.centeredHorizontalPadding(context, 20);

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: Responsive.width(context, 16),
                  top: Responsive.height(context, 8),
                  bottom: Responsive.height(context, 12),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: EdgeInsets.all(Responsive.scale(context, 12)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lightenColor(appColor, 0.1).withAlpha(20),
                        border: Border.all(
                          color: lightenColor(appColor, 0.3).withAlpha(180),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        color: lightenColor(appColor, 0.3).withAlpha(180),
                        size: Responsive.font(context, 13),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: hPad,
                      vertical: Responsive.height(context, 8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RangePickerCard(
                          rangeStart: _rangeStart,
                          rangeEnd: _rangeEnd,
                          rangeSelected: _rangeSelected,
                          calendarFocused: _calendarFocused,
                          rangeLabel: "water trend",
                          onRangeSelected: (start, end, focused) {
                            setState(() {
                              _calendarFocused = focused;
                              if (start != null) _rangeStart = start;
                              if (end != null) {
                                _rangeEnd = end;
                                _rangeSelected = true;
                                _chipIndex = 5;
                                _animationKey++;
                              } else {
                                _rangeSelected = false;
                              }
                            });
                          },
                          onPageChanged: (focused) {
                            setState(() => _calendarFocused = focused);
                          },
                          onClearRange: () {
                            setState(() {
                              _rangeStart = null;
                              _rangeEnd = null;
                              _rangeSelected = false;
                            });
                          },
                        ),

                        SizedBox(height: Responsive.height(context, 16)),

                        buildRangeChips(
                              context,
                              ['1W', '2W', '1M', '3M', 'All'],
                              _chipIndex,
                              _applyChip,
                            )
                            .animate(key: ValueKey(('chips', _animationKey)))
                            .fadeIn(duration: 250.ms),

                        SizedBox(height: Responsive.height(context, 24)),

                        sectionHeader("GRAPH", context),

                        _buildChart(context, entries)
                            .animate(key: ValueKey(('chart', _animationKey)))
                            .fadeIn(duration: 300.ms)
                            .slideY(
                              begin: 0.06,
                              duration: 300.ms,
                              curve: Curves.easeOut,
                            ),

                        if (entries.isNotEmpty) ...[
                          SizedBox(height: Responsive.height(context, 24)),
                          sectionHeader("INFO", context),
                          _buildStatTiles(context, entries)
                              .animate(key: ValueKey(('tiles', _animationKey)))
                              .fadeIn(delay: 50.ms, duration: 300.ms)
                              .slideY(
                                begin: 0.06,
                                delay: 50.ms,
                                duration: 300.ms,
                                curve: Curves.easeOut,
                              ),
                        ],

                        SizedBox(height: Responsive.height(context, 24)),

                        sectionHeader("ALL ENTRIES", context),

                        _buildLogEntries(context),

                        SizedBox(height: Responsive.height(context, 32)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
