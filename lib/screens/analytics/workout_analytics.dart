import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/services/user_data_manager.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:skeletonizer/skeletonizer.dart';
import '../../globals.dart';
import '../../utility/responsive.dart';
import '../../utility/unit_converter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'analytics_components.dart';
import '../premium_sheet.dart' show showPremiumSheet;

class WorkoutAnalyticsScreen extends ConsumerStatefulWidget {
  const WorkoutAnalyticsScreen({super.key});

  @override
  ConsumerState<WorkoutAnalyticsScreen> createState() =>
      _WorkoutAnalyticsScreenState();
}

class _WorkoutAnalyticsScreenState
    extends ConsumerState<WorkoutAnalyticsScreen> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  bool get isImperial =>
      ref.watch(userDataProvider.select((s) => s.value?.units == 'imperial'));

  // range state, default 1W
  int _chipIndex = 0;
  DateTime? _rangeStart = DateTime.now().subtract(const Duration(days: 6));
  DateTime? _rangeEnd = DateTime.now();
  bool _rangeSelected = true;
  DateTime _calendarFocused = DateTime.now();
  int _animationKey = 0;

  List<Map<String, dynamic>> _workouts = [];
  Map<String, int> _primaryMuscles = {};
  Map<String, int> _secondaryMuscles = {};
  Map<String, int> _prCounts = {'weight': 0, 'reps': 0, 'volume': 0};
  bool _loading = false;

  static const _chips = ['1W', '2W', '1M', '3M', 'All'];

  bool get _isPremium => ref.read(userDataProvider).value?.isPremium ?? false;
  DateTime get _cutoff => DateTime.now().subtract(const Duration(days: 13));

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/workout-analytics',
      screenClass: 'WorkoutAnalyticsScreen',
    );
    _load();
  }

  Future<void> _load() async {
    if (isGuest) return;
    setState(() => _loading = true);
    // free users capped at 2 weeks
    final effectiveStart =
        (!_isPremium && (_rangeStart == null || _rangeStart!.isBefore(_cutoff)))
        ? _cutoff
        : _rangeStart;
    try {
      final since = effectiveStart != null
          ? '${effectiveStart.year}-${effectiveStart.month.toString().padLeft(2, '0')}-${effectiveStart.day.toString().padLeft(2, '0')}'
          : null;
      final url = since != null
          ? 'workout_analytics?since=$since'
          : 'workout_analytics';
      final response = await authenticatedGet(url);
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final all = (data['workouts'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        // filter to range end
        final end = _rangeEnd;
        final filtered = end == null
            ? all
            : all.where((w) {
                final d = DateTime.tryParse(w['date'] as String? ?? '');
                return d == null || !d.isAfter(end);
              }).toList();
        setState(() {
          _workouts = filtered;
          // muscle frequency maps: muscle name -> number of workouts it appeared in
          _primaryMuscles = Map<String, int>.from(
            (data['primary_muscles'] as Map? ?? {}).map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ),
          );
          _secondaryMuscles = Map<String, int>.from(
            (data['secondary_muscles'] as Map? ?? {}).map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ),
          );
          // pr counts by type for the selected range
          final pr = data['pr_counts'] as Map? ?? {};
          _prCounts = {
            'weight': (pr['weight'] as num? ?? 0).toInt(),
            'reps': (pr['reps'] as num? ?? 0).toInt(),
            'volume': (pr['volume'] as num? ?? 0).toInt(),
          };
          _animationKey++;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyChip(int index) {
    if (showAnalyticsPremiumGate(context, ref, appColor, _isPremium, index)) {
      return;
    }
    final now = DateTime.now();
    DateTime? start;
    switch (index) {
      case 0:
        start = now.subtract(const Duration(days: 6));
        break;
      case 1:
        start = now.subtract(const Duration(days: 13));
        break;
      case 2:
        start = DateTime(now.year, now.month - 1, now.day);
        break;
      case 3:
        start = DateTime(now.year, now.month - 3, now.day);
        break;
      case 4:
        start = null;
        break;
    }
    setState(() {
      _chipIndex = index;
      _rangeStart = start;
      _rangeEnd = now;
      _rangeSelected = true;
      _calendarFocused = now;
    });
    _load();
  }

  // aggregated totals across the filtered range
  int get _totalWorkouts => _workouts.length;
  double get _totalVolumeKg => _workouts.fold(
    0.0,
    (s, w) => s + ((w['volume_kg'] as num?)?.toDouble() ?? 0),
  );
  int get _totalDurationSeconds => _workouts.fold(
    0,
    (s, w) => s + ((w['duration_seconds'] as num?)?.toInt() ?? 0),
  );
  int get _avgDurationSeconds =>
      _totalWorkouts == 0 ? 0 : _totalDurationSeconds ~/ _totalWorkouts;

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final accent = onTheme(appColor);
    final dim = onTheme(appColor);
    final hPad = Responsive.centeredHorizontalPadding(context, 20);

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad).copyWith(
                  top: Responsive.height(context, 8),
                  bottom: Responsive.height(context, 12),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: EdgeInsets.all(Responsive.scale(context, 10)),
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
                  ],
                ),
              ),

              Expanded(
                child: ScrollConfiguration(
                  behavior: NoGlowScrollBehavior(),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: hPad,
                    ).copyWith(bottom: Responsive.height(context, 24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                  width: 1.5,
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

                        // range chips
                        buildRangeChips(
                          context,
                          _chips,
                          _chipIndex,
                          (i) => _applyChip(i),
                          appColor: appColor,
                          shimmerIndices: _isPremium ? [] : [2, 3, 4],
                          onLockedTap: _isPremium
                              ? null
                              : analyticsLockedChipTap(context, ref, appColor),
                        ),
                        SizedBox(height: Responsive.height(context, 12)),

                        // calendar range picker
                        RangePickerCard(
                          rangeStart: _rangeStart,
                          rangeEnd: _rangeEnd,
                          rangeSelected: _rangeSelected,
                          calendarFocused: _calendarFocused,
                          rangeLabel: 'workouts',
                          onRangeSelected: (start, end, focused) {
                            setState(() {
                              _rangeStart = start;
                              _rangeEnd = end;
                              _rangeSelected = start != null && end != null;
                              _calendarFocused = focused;
                              _chipIndex = -1;
                            });
                            if (_rangeSelected) _load();
                          },
                          onPageChanged: (f) =>
                              setState(() => _calendarFocused = f),
                          onClearRange: () {
                            setState(() {
                              _rangeStart = null;
                              _rangeEnd = null;
                              _rangeSelected = false;
                              _chipIndex = -1;
                            });
                          },
                          firstDay: _isPremium ? null : _cutoff,
                        ),
                        SizedBox(height: Responsive.height(context, 20)),

                        Skeletonizer(
                          enabled: _loading,
                          effect: ShimmerEffect(
                            baseColor: cardColors(appColor).iconBox,
                            highlightColor: cardColors(appColor).border,
                            duration: const Duration(milliseconds: 1200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              sectionHeader(
                                "OVERVIEW",
                                context,
                                appColor: appColor,
                              ),
                              _buildSummaryCards(context, accent, dim)
                                  .animate(
                                    key: ValueKey(('summary', _animationKey)),
                                  )
                                  .fadeIn(duration: 300.ms)
                                  .slideY(begin: 0.1, curve: Curves.easeOut),

                              SizedBox(height: Responsive.height(context, 16)),

                              SizedBox(height: Responsive.height(context, 24)),
                              sectionHeader(
                                "PERSONAL RECORDS",
                                context,
                                appColor: appColor,
                              ),
                              _buildPrCard(context, accent, dim)
                                  .animate(key: ValueKey(('pr', _animationKey)))
                                  .fadeIn(delay: 40.ms, duration: 300.ms)
                                  .slideY(begin: 0.1, curve: Curves.easeOut),

                              SizedBox(height: Responsive.height(context, 16)),

                              SizedBox(height: Responsive.height(context, 24)),
                              sectionHeader(
                                "MUSCLE GROUPS",
                                context,
                                appColor: appColor,
                              ),
                              _buildMuscleRadar(context, accent, dim)
                                  .animate(
                                    key: ValueKey(('radar', _animationKey)),
                                  )
                                  .fadeIn(delay: 80.ms, duration: 300.ms)
                                  .slideY(begin: 0.1, curve: Curves.easeOut),

                              SizedBox(height: Responsive.height(context, 24)),
                              sectionHeader(
                                "VOLUME TREND",
                                context,
                                appColor: appColor,
                              ),
                              _buildVolumeChart(context, accent, dim)
                                  .animate(
                                    key: ValueKey(('volume', _animationKey)),
                                  )
                                  .fadeIn(delay: 120.ms, duration: 300.ms)
                                  .slideY(begin: 0.1, curve: Curves.easeOut),

                              SizedBox(height: Responsive.height(context, 24)),
                              sectionHeader(
                                "DURATION TREND",
                                context,
                                appColor: appColor,
                              ),
                              _buildDurationChart(context, accent, dim)
                                  .animate(
                                    key: ValueKey(('duration', _animationKey)),
                                  )
                                  .fadeIn(delay: 160.ms, duration: 300.ms)
                                  .slideY(begin: 0.1, curve: Curves.easeOut),
                            ],
                          ),
                        ),
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

  Widget _buildSummaryCards(BuildContext context, Color accent, Color dim) {
    final volDisplay = isImperial
        ? '${UnitConverter.displayWeight(_totalVolumeKg, imperial: true)} lbs'
        : '${_totalVolumeKg.toStringAsFixed(0)} kg';
    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 20),
        vertical: Responsive.height(context, 18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statCell(context, '$_totalWorkouts', 'Workouts', accent, dim),
          _vDivider(context),
          _statCell(context, volDisplay, 'Total Volume', accent, dim),
          _vDivider(context),
          _statCell(
            context,
            _formatDuration(_avgDurationSeconds),
            'Avg Duration',
            accent,
            dim,
          ),
        ],
      ),
    );
  }

  Widget _buildPrCard(BuildContext context, Color accent, Color dim) {
    final total =
        (_prCounts['weight'] ?? 0) +
        (_prCounts['reps'] ?? 0) +
        (_prCounts['volume'] ?? 0);
    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 20),
        vertical: Responsive.height(context, 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Personal Records',
                style: GoogleFonts.manrope(
                  color: onTheme(appColor),
                  fontSize: Responsive.font(context, 14),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$total total',
                style: GoogleFonts.manrope(
                  color: dim,
                  fontSize: Responsive.font(context, 12),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.height(context, 14)),
          Row(
            children: [
              _prCell(
                context,
                '${_prCounts['weight'] ?? 0}',
                'Weight PRs',
                accent,
                dim,
              ),
              _vDivider(context),
              _prCell(
                context,
                '${_prCounts['reps'] ?? 0}',
                'Rep PRs',
                accent,
                dim,
              ),
              _vDivider(context),
              _prCell(
                context,
                '${_prCounts['volume'] ?? 0}',
                'Volume PRs',
                accent,
                dim,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _prCell(
    BuildContext context,
    String value,
    String label,
    Color accent,
    Color dim,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              color: accent,
              fontSize: Responsive.font(context, 22),
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: dim,
              fontSize: Responsive.font(context, 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleRadar(BuildContext context, Color accent, Color dim) {
    // top 6 primary muscles by frequency become the radar axes
    final sorted = _primaryMuscles.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();

    // RadarChart requires at least 3 entries or it throws an assertion error
    if (top.length < 3) {
      return SizedBox(
        width: double.infinity,
        child: frostedGlassCard(
          context,
          color: appColor,
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 20),
            vertical: Responsive.height(context, 16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Muscle Groups Worked',
                style: GoogleFonts.manrope(
                  color: onTheme(appColor),
                  fontSize: Responsive.font(context, 14),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: Responsive.height(context, 8)),
              Text(
                'At least 3 primary muscles are needed to view the Radar Chart',
                style: GoogleFonts.manrope(
                  color: onTheme(appColor),
                  fontSize: Responsive.font(context, 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dataEntries = top
        .map((e) => RadarEntry(value: e.value.toDouble()))
        .toList();

    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Muscle Groups Worked',
            style: GoogleFonts.manrope(
              color: onTheme(appColor),
              fontSize: Responsive.font(context, 14),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'primary muscles, by frequency',
            style: GoogleFonts.manrope(
              color: onTheme(appColor).withAlpha(140),
              fontSize: Responsive.font(context, 11),
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          SizedBox(
            height: Responsive.height(context, 220),
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                tickCount: 3,
                ticksTextStyle: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 0,
                ),
                radarBorderData: BorderSide(
                  color: Colors.white.withAlpha(20),
                  width: 1,
                ),
                gridBorderData: BorderSide(
                  color: Colors.white.withAlpha(12),
                  width: 1,
                ),
                tickBorderData: BorderSide(
                  color: Colors.white.withAlpha(10),
                  width: 1,
                ),
                getTitle: (index, angle) {
                  if (index >= top.length) return RadarChartTitle(text: '');
                  final name = top[index].key;
                  final label = name.length > 10
                      ? '${name[0].toUpperCase()}${name.substring(1, 8)}.'
                      : '${name[0].toUpperCase()}${name.substring(1)}';
                  return RadarChartTitle(text: label, angle: 0);
                },
                titleTextStyle: GoogleFonts.manrope(
                  color: dim,
                  fontSize: Responsive.font(context, 10),
                  fontWeight: FontWeight.w600,
                ),
                titlePositionPercentageOffset: 0.15,
                dataSets: [
                  RadarDataSet(
                    dataEntries: dataEntries,
                    fillColor: accent.withAlpha(40),
                    borderColor: accent,
                    borderWidth: 2,
                    entryRadius: 3,
                  ),
                ],
              ),
            ),
          ),
          if (_secondaryMuscles.isNotEmpty) ...[
            SizedBox(height: Responsive.height(context, 12)),
            Divider(color: onTheme(appColor).withAlpha(40), height: 1),
            SizedBox(height: Responsive.height(context, 10)),
            Text(
              'Secondary muscles',
              style: GoogleFonts.manrope(
                color: dim,
                fontSize: Responsive.font(context, 11),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: Responsive.height(context, 8)),
            Wrap(
              spacing: Responsive.width(context, 6),
              runSpacing: Responsive.height(context, 4),
              children: [
                for (final e in (List.of(
                  _secondaryMuscles.entries,
                )..sort((a, b) => b.value.compareTo(a.value))).take(8))
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.width(context, 8),
                      vertical: Responsive.height(context, 3),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(
                        Responsive.scale(context, 20),
                      ),
                      border: Border.all(
                        color: cardColors(appColor).border,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '${e.key[0].toUpperCase()}${e.key.substring(1)} ×${e.value}',
                      style: GoogleFonts.manrope(
                        color: dim,
                        fontSize: Responsive.font(context, 10),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCell(
    BuildContext context,
    String value,
    String label,
    Color accent,
    Color dim,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            color: onTheme(appColor),
            fontSize: Responsive.font(context, 16),
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: onTheme(appColor).withAlpha(140),
            fontSize: Responsive.font(context, 11),
          ),
        ),
      ],
    );
  }

  Widget _vDivider(BuildContext context) => Container(
    width: 1,
    height: Responsive.height(context, 32),
    color: onTheme(appColor).withAlpha(120),
  );

  Widget _workoutChartEmptyState(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: frostedGlassCard(
        context,
        color: appColor,
        padding: EdgeInsets.all(Responsive.scale(context, 20)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: Responsive.height(context, 28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedChartHistogram,
                color: onTheme(appColor).withAlpha(120),
                size: Responsive.scale(context, 32),
              ),
              SizedBox(height: Responsive.height(context, 10)),
              Text(
                "No workouts in this range",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 13),
                  color: onTheme(appColor).withAlpha(140),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeChart(BuildContext context, Color accent, Color dim) {
    // group by date, sum volume
    final Map<String, double> byDate = {};
    for (final w in _workouts) {
      final d = w['date'] as String? ?? '';
      byDate[d] =
          (byDate[d] ?? 0) + ((w['volume_kg'] as num?)?.toDouble() ?? 0);
    }
    final sorted = byDate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (sorted.isEmpty) return _workoutChartEmptyState(context);

    final spots = sorted.asMap().entries.map((e) {
      final volKg = e.value.value;
      final vol = isImperial ? volKg * 2.20462 : volKg;
      return FlSpot(e.key.toDouble(), vol);
    }).toList();

    final maxY = spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);

    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isImperial ? 'lbs' : 'kg',
            style: GoogleFonts.manrope(
              color: onTheme(appColor).withAlpha(140),
              fontSize: Responsive.font(context, 11),
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          SizedBox(
            height: Responsive.height(context, 160),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.white.withAlpha(12), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchSpotThreshold: 20,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) =>
                        darkenColor(appColor, 0.1).withAlpha(220),
                    getTooltipItems: (touched) => touched.map((s) {
                      final i = s.spotIndex;
                      final dateStr = i >= 0 && i < sorted.length
                          ? formatDateKeyShort(sorted[i].key)
                          : '';
                      final unit = isImperial ? 'lbs' : 'kg';
                      return LineTooltipItem(
                        '$dateStr\n',
                        GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 11),
                          color: dim,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: '${s.y.toStringAsFixed(0)} $unit',
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
                      reservedSize: Responsive.width(context, 40),
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: GoogleFonts.manrope(
                          color: onTheme(appColor).withAlpha(140),
                          fontSize: Responsive.font(context, 9),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: sorted.length <= 14,
                      interval: sorted.length <= 7 ? 1 : 2,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= sorted.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          formatDateKeyShort(sorted[i].key),
                          style: GoogleFonts.manrope(
                            color: onTheme(appColor).withAlpha(140),
                            fontSize: Responsive.font(context, 9),
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
                ),
                minY: 0,
                maxY: maxY * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: accent,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: spots.length <= 14,
                      getDotPainter: (p, q, r, s) => FlDotCirclePainter(
                        radius: 3,
                        color: accent,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: accent.withAlpha(30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChart(BuildContext context, Color accent, Color dim) {
    final sorted = List<Map<String, dynamic>>.from(_workouts)
      ..sort(
        (a, b) =>
            (a['date'] as String? ?? '').compareTo(b['date'] as String? ?? ''),
      );

    final spots = sorted.asMap().entries.map((e) {
      final mins = ((e.value['duration_seconds'] as num?)?.toInt() ?? 0) / 60.0;
      return FlSpot(e.key.toDouble(), mins);
    }).toList();

    final maxY = spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);
    if (maxY == 0) return _workoutChartEmptyState(context);

    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'minutes',
            style: GoogleFonts.manrope(
              color: onTheme(appColor).withAlpha(140),
              fontSize: Responsive.font(context, 11),
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          SizedBox(
            height: Responsive.height(context, 160),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.white.withAlpha(12), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchSpotThreshold: 20,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) =>
                        darkenColor(appColor, 0.1).withAlpha(220),
                    getTooltipItems: (touched) => touched.map((s) {
                      final i = s.spotIndex;
                      final dateStr = i >= 0 && i < sorted.length
                          ? formatDateKeyShort(
                              sorted[i]['date'] as String? ?? '',
                            )
                          : '';
                      final mins = s.y.toInt();
                      return LineTooltipItem(
                        '$dateStr\n',
                        GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 11),
                          color: dim,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: '${mins}m',
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
                      reservedSize: Responsive.width(context, 40),
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}m',
                        style: GoogleFonts.manrope(
                          color: onTheme(appColor).withAlpha(140),
                          fontSize: Responsive.font(context, 9),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: sorted.length <= 14,
                      interval: sorted.length <= 7 ? 1 : 2,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= sorted.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          formatDateKeyShort(
                            sorted[i]['date'] as String? ?? '',
                          ),
                          style: GoogleFonts.manrope(
                            color: onTheme(appColor).withAlpha(140),
                            fontSize: Responsive.font(context, 9),
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
                ),
                minY: 0,
                maxY: maxY * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: onTheme(appColor),
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: spots.length <= 14,
                      getDotPainter: (p, q, r, s) => FlDotCirclePainter(
                        radius: 3,
                        color: onTheme(appColor),
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lightenColor(appColor, 0.30).withAlpha(25),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
