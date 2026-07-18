import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/providers/weight_logs_provider.dart'
    show weightLogsProvider, weightLogsAnalyticsProvider;
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
import '../premium_sheet.dart' show showPremiumSheet;

class WeightAnalyticsScreen extends ConsumerStatefulWidget {
  const WeightAnalyticsScreen({super.key});

  @override
  ConsumerState<WeightAnalyticsScreen> createState() =>
      _WeightAnalyticsScreenState();
}

class _WeightAnalyticsScreenState extends ConsumerState<WeightAnalyticsScreen> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  bool get isImperial =>
      ref.watch(userDataProvider.select((s) => s.value?.units == 'imperial'));

  bool get _isPremium => ref.read(userDataProvider).value?.isPremium ?? false;
  DateTime get _cutoff => DateTime.now().subtract(const Duration(days: 13));

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
      screenName: '/weight/analytics',
      screenClass: 'WeightAnalyticsScreen',
    );
    _applyChip(0);
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  // Sets the chart range based on the selected quick-select chip
  void _applyChip(int index) {
    if (showAnalyticsPremiumGate(context, ref, appColor, _isPremium, index)) {
      return;
    }
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

  // Returns all weight entries sorted chronologically oldest-first
  List<MapEntry<String, double>> _sortedEntries() {
    final byDate = ref.watch(weightLogsAnalyticsProvider).value ?? {};
    final entries = byDate.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  // Filters sorted entries to only those within the selected date range
  List<MapEntry<String, double>> _entriesInRange() {
    if (_rangeStart == null || _rangeEnd == null) return [];
    final startKey = _rangeStart!.toIso8601String().substring(0, 10);
    final endKey = _rangeEnd!.toIso8601String().substring(0, 10);
    return _sortedEntries()
        .where(
          (e) => e.key.compareTo(startKey) >= 0 && e.key.compareTo(endKey) <= 0,
        )
        .toList();
  }

  String _dateKeyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _deleteEntry(String dateKey) async {
    await ref.read(weightLogsProvider.notifier).deleteWeightLog(dateKey);
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
    final raw = double.tryParse(_addController.text.trim());
    if (raw == null) return;
    final kg = isImperial ? UnitConverter.lbsToKg(raw) : raw;
    final key = _dateKeyFor(_addDate);
    setState(() => _isAdding = true);
    await ref.read(weightLogsProvider.notifier).updateWeightLog(key, kg);
    if (mounted) {
      setState(() {
        _isAdding = false;
        _addController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry added'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildChart(
    BuildContext context,
    List<MapEntry<String, double>> entries,
  ) {
    final accent = onTheme(appColor);
    final dimAccent = onTheme(appColor);
    final goalKg = ref.watch(userDataProvider).value?.weightKgGoal;

    if (entries.isEmpty) {
      return frostedGlassCard(
        context,
        color: appColor,
        padding: EdgeInsets.all(Responsive.scale(context, 20)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: Responsive.height(context, 28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: _rangeSelected
                    ? HugeIcons.strokeRoundedWeightScale
                    : HugeIcons.strokeRoundedCalendar02,
                color: onTheme(appColor).withAlpha(120),
                size: Responsive.scale(context, 28),
              ),
              SizedBox(height: Responsive.height(context, 10)),
              Text(
                _rangeSelected
                    ? "No weight logged in this range"
                    : "Pick a range to view your weight trend",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 13),
                  color: dimAccent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    double toDisplay(double kg) => isImperial
        ? double.parse(UnitConverter.displayWeight(kg, imperial: true))
        : kg;

    final spots = <FlSpot>[];
    for (int i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), toDisplay(entries[i].value)));
    }

    final allY = spots.map((s) => s.y).toList();
    if (goalKg != null) allY.add(toDisplay(goalKg));
    final minY = allY.reduce((a, b) => a < b ? a : b);
    final maxY = allY.reduce((a, b) => a > b ? a : b);
    final yPad = (maxY - minY) == 0 ? 2.0 : (maxY - minY) * 0.2;

    final goalLine = goalKg != null
        ? [
            HorizontalLine(
              y: toDisplay(goalKg),
              color: accent.withAlpha(160),
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                labelResolver: (_) =>
                    '${isImperial ? UnitConverter.displayWeight(goalKg, imperial: true) : goalKg.toStringAsFixed(1)} ${UnitConverter.weightUnit(imperial: isImperial)} goal',
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
      color: appColor,
      padding: EdgeInsets.all(Responsive.scale(context, 16)),
      child: SizedBox(
        height: Responsive.height(context, 220),
        child: LineChart(
          LineChartData(
            minY: minY - yPad,
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
                        text:
                            '${s.y.toStringAsFixed(1)} ${UnitConverter.weightUnit(imperial: isImperial)}',
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
                        val.toStringAsFixed(1),
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 10),
                          fontWeight: FontWeight.w600,
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
                          fontWeight: FontWeight.w600,
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
    List<MapEntry<String, double>> entries,
  ) {
    final unit = UnitConverter.weightUnit(imperial: isImperial);

    String fmt(double kg) => isImperial
        ? '${UnitConverter.displayWeight(kg, imperial: true)} $unit'
        : '${kg.toStringAsFixed(1)} $unit';

    // entries are sorted oldest-first, so first = start of range, last = most recent
    final first = entries.isNotEmpty ? entries.first.value : null;
    final last = entries.isNotEmpty ? entries.last.value : null;
    // positive delta = gained, negative = lost
    final delta = (first != null && last != null) ? last - first : null;

    String deltaStr = '--';
    if (delta != null) {
      final sign = delta > 0 ? '+' : '';
      deltaStr = isImperial
          ? '$sign${UnitConverter.displayWeight(delta.abs(), imperial: true)} $unit'
          : '$sign${delta.toStringAsFixed(1)} $unit';
    }

    return Row(
      children: [
        analyticsStatTile(
          context,
          appColor,
          icon: HugeIcons.strokeRoundedWeightScale,
          label: "Start",
          value: first != null ? fmt(first) : '--',
        ),
        SizedBox(width: Responsive.width(context, 10)),
        analyticsStatTile(
          context,
          appColor,
          icon: HugeIcons.strokeRoundedWeightScale,
          label: "Current",
          value: last != null ? fmt(last) : '--',
        ),
        SizedBox(width: Responsive.width(context, 10)),
        analyticsStatTile(
          context,
          appColor,
          icon: HugeIcons.strokeRoundedActivity01,
          label: "Change",
          value: deltaStr,
        ),
      ],
    );
  }

  Widget _buildLogEntries(BuildContext context) {
    final unit = UnitConverter.weightUnit(imperial: isImperial);
    final accent = onTheme(appColor);
    final dimAccent = onTheme(appColor);
    final all = _sortedEntries().reversed.toList();

    return frostedGlassCard(
      context,
      color: appColor,
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
                      LengthLimitingTextInputFormatter(4),
                    ],
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 14),
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add weight ($unit)',
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
                      appColor: appColor,
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
                maxHeight: Responsive.height(context, 260),
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
                                      ? '${UnitConverter.displayWeight(all[i].value, imperial: true)} $unit'
                                      : '${all[i].value.toStringAsFixed(1)} $unit',
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 14),
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                                SizedBox(width: Responsive.width(context, 12)),
                                GestureDetector(
                                  onTap: () {
                                    // first tap arms the delete, second tap confirms it
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
                                              12,
                                            ),
                                            fontWeight: FontWeight.w700,
                                            color: onTheme(appColor),
                                          ),
                                        )
                                      : HugeIcon(
                                          icon: HugeIcons.strokeRoundedDelete02,
                                          color: onTheme(appColor),
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
    final entries = _entriesInRange();
    final hPad = Responsive.centeredHorizontalPadding(context, 20);

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
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
                        color: cardColors(appColor).iconBox,
                        border: Border.all(
                          color: cardColors(appColor).iconBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        color: cardColors(appColor).onCard,
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
                        if (!_isPremium) ...[
                          GestureDetector(
                            onTap: () => showPremiumSheet(context, ref),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 14),
                                vertical: Responsive.height(context, 10),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(10),
                                borderRadius: BorderRadius.circular(
                                  Responsive.scale(context, 12),
                                ),
                                border: Border.all(
                                  color: cardColors(appColor).border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  proChip(context),
                                  SizedBox(width: Responsive.width(context, 8)),
                                  Expanded(
                                    child: Text(
                                      'Free plan shows the last 14 days. Upgrade for full history.',
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(context, 12),
                                        color: onTheme(appColor),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Upgrade',
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 12),
                                      color: onTheme(appColor),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 12)),
                        ],
                        RangePickerCard(
                          rangeStart: _rangeStart,
                          rangeEnd: _rangeEnd,
                          rangeSelected: _rangeSelected,
                          calendarFocused: _calendarFocused,
                          rangeLabel: "weight trend",
                          firstDay: _isPremium ? null : _cutoff,
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
                              appColor: appColor,
                              shimmerIndices: _isPremium ? [] : [2, 3, 4],
                              onLockedTap: _isPremium
                                  ? null
                                  : analyticsLockedChipTap(
                                      context,
                                      ref,
                                      appColor,
                                    ),
                            )
                            .animate(key: ValueKey(('chips', _animationKey)))
                            .fadeIn(duration: 250.ms),

                        SizedBox(height: Responsive.height(context, 24)),

                        sectionHeader("GRAPH", context, appColor: appColor),

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
                          sectionHeader("INFO", context, appColor: appColor),
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

                        sectionHeader(
                          "ALL ENTRIES",
                          context,
                          appColor: appColor,
                        ),

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
