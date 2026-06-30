import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/globals.dart';
import '/utility/responsive.dart';

// placeholder data shapes used until the backend is wired up
class _RoutinePreview {
  final String name;
  final int exerciseCount;
  final List<String> muscles;
  final List<String> exercises;
  final int? estimatedMinutes;
  final String? creatorUsername;

  const _RoutinePreview({
    required this.name,
    required this.exerciseCount,
    required this.muscles,
    required this.exercises,
    this.estimatedMinutes,
    this.creatorUsername,
  });
}

// stub data shown until real backend data is fetched
const _featuredStubs = [
  _RoutinePreview(
    name: 'Push Day',
    exerciseCount: 6,
    muscles: ['Chest', 'Shoulders', 'Triceps'],
    exercises: [
      'Bench Press',
      'Incline DB Press',
      'Overhead Press',
      'Tricep Pushdown',
    ],
    estimatedMinutes: 60,
  ),
  _RoutinePreview(
    name: 'Pull Day',
    exerciseCount: 6,
    muscles: ['Back', 'Biceps'],
    exercises: ['Deadlift', 'Pull-Ups', 'Barbell Row', 'Hammer Curl'],
    estimatedMinutes: 55,
  ),
  _RoutinePreview(
    name: 'Leg Day',
    exerciseCount: 7,
    muscles: ['Quadriceps', 'Hamstrings', 'Glutes'],
    exercises: ['Squat', 'Romanian Deadlift', 'Leg Press', 'Lunges'],
    estimatedMinutes: 70,
  ),
];

const _communityStubs = [
  _RoutinePreview(
    name: 'Morning Upper Body',
    exerciseCount: 5,
    muscles: ['Chest', 'Shoulders'],
    exercises: ['Push-Up Warm-Up', 'Overhead Press', 'Skull Crushers'],
    creatorUsername: 'marcus_lifts',
  ),
  _RoutinePreview(
    name: 'Core Crusher',
    exerciseCount: 6,
    muscles: ['Abdominals'],
    exercises: ['Plank Hold', 'Russian Twist', 'Hanging Knee Raise'],
    creatorUsername: 'sarafit',
  ),
  _RoutinePreview(
    name: 'Full Body Blast',
    exerciseCount: 8,
    muscles: ['Chest', 'Back', 'Quadriceps'],
    exercises: ['Squat', 'Bench Press', 'Pull-Ups', 'Deadlift'],
    creatorUsername: 'coach_dan',
  ),
];

class BrowseRoutinesScreen extends StatefulWidget {
  const BrowseRoutinesScreen({super.key});

  @override
  State<BrowseRoutinesScreen> createState() => _BrowseRoutinesScreenState();
}

class _BrowseRoutinesScreenState extends State<BrowseRoutinesScreen> {
  late final VoidCallback _colorListener;

  @override
  void initState() {
    super.initState();
    _colorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_colorListener);
  }

  @override
  void dispose() {
    appColorNotifier.removeListener(_colorListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(appColorNotifier.value);
    final bg = hsl.lightness > 0.25
        ? darkenColor(
            appColorNotifier.value,
            (hsl.lightness - 0.22).clamp(0.0, 0.3),
          )
        : appColorNotifier.value;
    final c = cardColors(appColorNotifier.value);
    // derive text colors from card surface the same way the home screen does
    final accent = c.onCard;
    final dim = c.onCard.withAlpha(180);
    final subtle = c.onCard.withAlpha(120);

    return Container(
      decoration: BoxDecoration(color: bg),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, accent, dim, c),
              Container(height: 1, color: c.border),
              Expanded(
                child: ScrollConfiguration(
                  behavior: NoGlowScrollBehavior(),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: Responsive.height(context, 24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionHeader(
                          'FEATURED',
                          context,
                          padding: EdgeInsets.only(
                            left: Responsive.centeredHorizontalPadding(
                              context,
                              20,
                            ),
                            top: Responsive.height(context, 16),
                            bottom: Responsive.height(context, 12),
                          ),
                        ),
                        _buildFeaturedRow(context, accent, dim, subtle, c),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.centeredHorizontalPadding(
                              context,
                              20,
                            ),
                            vertical: Responsive.height(context, 20),
                          ),
                          child: Divider(color: c.border, height: 1),
                        ),
                        sectionHeader(
                          'COMMUNITY',
                          context,
                          padding: EdgeInsets.only(
                            left: Responsive.centeredHorizontalPadding(
                              context,
                              20,
                            ),
                            bottom: Responsive.height(context, 12),
                          ),
                        ),
                        _buildCommunityList(context, accent, dim, subtle, c),
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

  Widget _buildHeader(
    BuildContext context,
    Color accent,
    Color dim,
    dynamic c,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.centeredHorizontalPadding(context, 20),
        vertical: Responsive.height(context, 14),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: EdgeInsets.all(Responsive.scale(context, 10)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appColorNotifier.value.withAlpha(40),
                border: Border.all(color: c.border, width: 1),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: accent,
                size: Responsive.scale(context, 14),
              ),
            ),
          ),
          SizedBox(width: Responsive.width(context, 14)),
          Text(
            'Browse Routines',
            style: GoogleFonts.manrope(
              color: accent,
              fontSize: Responsive.font(context, 20),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // horizontally scrolling row of featured routine cards
  Widget _buildFeaturedRow(
    BuildContext context,
    Color accent,
    Color dim,
    Color subtle,
    dynamic c,
  ) {
    final hPad = Responsive.centeredHorizontalPadding(context, 20);
    return SizedBox(
      height: Responsive.height(context, 230),
      child: ScrollConfiguration(
        behavior: NoGlowScrollBehavior().copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: hPad),
          itemCount: _featuredStubs.length,
          separatorBuilder: (_, _) =>
              SizedBox(width: Responsive.width(context, 12)),
          itemBuilder: (context, i) => _buildFeaturedCard(
            context,
            _featuredStubs[i],
            accent,
            dim,
            subtle,
            c,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(
    BuildContext context,
    _RoutinePreview routine,
    Color accent,
    Color dim,
    Color subtle,
    dynamic c,
  ) {
    return SizedBox(
      width: Responsive.width(context, 220),
      height: double.infinity,
      child: _styledCard(
        context,
        c,
        padding: EdgeInsets.all(Responsive.scale(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 8),
                    vertical: Responsive.height(context, 3),
                  ),
                  decoration: BoxDecoration(
                    color: appColorNotifier.value.withAlpha(50),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: appColorNotifier.value.withAlpha(100),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: accent,
                        size: Responsive.scale(context, 10),
                      ),
                      SizedBox(width: Responsive.width(context, 4)),
                      Text(
                        'FEATURED',
                        style: GoogleFonts.manrope(
                          color: accent,
                          fontSize: Responsive.font(context, 9),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // add to my routines placeholder
                GestureDetector(
                  onTap: () {},
                  child: Icon(
                    Icons.bookmark_add_outlined,
                    color: subtle,
                    size: Responsive.scale(context, 20),
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.height(context, 10)),
            Text(
              routine.name,
              style: GoogleFonts.manrope(
                color: accent,
                fontSize: Responsive.font(context, 15),
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${routine.exerciseCount} exercises${routine.estimatedMinutes != null ? ' · ${routine.estimatedMinutes} min' : ''}',
              style: GoogleFonts.manrope(
                color: dim,
                fontSize: Responsive.font(context, 11),
              ),
            ),
            SizedBox(height: Responsive.height(context, 8)),
            Wrap(
              spacing: Responsive.width(context, 4),
              runSpacing: Responsive.height(context, 4),
              children: routine.muscles
                  .map((m) => _muscleChip(context, m, accent))
                  .toList(),
            ),
            SizedBox(height: Responsive.height(context, 8)),
            for (final ex in routine.exercises.take(3))
              Padding(
                padding: EdgeInsets.only(bottom: Responsive.height(context, 2)),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      color: dim.withAlpha(100),
                      size: Responsive.scale(context, 5),
                    ),
                    SizedBox(width: Responsive.width(context, 6)),
                    Expanded(
                      child: Text(
                        ex,
                        style: GoogleFonts.manrope(
                          color: dim,
                          fontSize: Responsive.font(context, 11),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (routine.exercises.length > 3)
              Text(
                '+${routine.exercises.length - 3} more',
                style: GoogleFonts.manrope(
                  color: subtle,
                  fontSize: Responsive.font(context, 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityList(
    BuildContext context,
    Color accent,
    Color dim,
    Color subtle,
    dynamic c,
  ) {
    final hPad = Responsive.centeredHorizontalPadding(context, 20);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        children: [
          for (int i = 0; i < _communityStubs.length; i++) ...[
            _buildCommunityCard(
              context,
              _communityStubs[i],
              accent,
              dim,
              subtle,
              c,
            ),
            if (i < _communityStubs.length - 1)
              SizedBox(height: Responsive.height(context, 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildCommunityCard(
    BuildContext context,
    _RoutinePreview routine,
    Color accent,
    Color dim,
    Color subtle,
    dynamic c,
  ) {
    return _styledCard(
      context,
      c,
      padding: EdgeInsets.all(Responsive.scale(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.name,
                      style: GoogleFonts.manrope(
                        color: accent,
                        fontSize: Responsive.font(context, 15),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          color: subtle,
                          size: Responsive.scale(context, 12),
                        ),
                        SizedBox(width: Responsive.width(context, 4)),
                        Text(
                          '@${routine.creatorUsername}',
                          style: GoogleFonts.manrope(
                            color: dim,
                            fontSize: Responsive.font(context, 11),
                          ),
                        ),
                        Text(
                          ' · ${routine.exerciseCount} exercises',
                          style: GoogleFonts.manrope(
                            color: subtle,
                            fontSize: Responsive.font(context, 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.height(context, 10)),
          Wrap(
            spacing: Responsive.width(context, 4),
            runSpacing: Responsive.height(context, 4),
            children: routine.muscles
                .map((m) => _muscleChip(context, m, accent))
                .toList(),
          ),
          SizedBox(height: Responsive.height(context, 8)),
          for (final ex in routine.exercises.take(3))
            Padding(
              padding: EdgeInsets.only(bottom: Responsive.height(context, 2)),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    color: dim.withAlpha(100),
                    size: Responsive.scale(context, 5),
                  ),
                  SizedBox(width: Responsive.width(context, 6)),
                  Expanded(
                    child: Text(
                      ex,
                      style: GoogleFonts.manrope(
                        color: dim,
                        fontSize: Responsive.font(context, 12),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (routine.exercises.length > 3)
            Text(
              '+${routine.exercises.length - 3} more',
              style: GoogleFonts.manrope(
                color: subtle,
                fontSize: Responsive.font(context, 10),
              ),
            ),
          SizedBox(height: Responsive.height(context, 12)),
          // add to my routines placeholder
          GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 11),
              ),
              decoration: BoxDecoration(
                color: appColorNotifier.value.withAlpha(55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: appColorNotifier.value.withAlpha(130),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_add_outlined,
                    color: accent,
                    size: Responsive.scale(context, 15),
                  ),
                  SizedBox(width: Responsive.width(context, 6)),
                  Text(
                    'Add to My Routines',
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 13),
                      fontWeight: FontWeight.w700,
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

  // card surface matching the home screen style using cardColors gradient and border
  Widget _styledCard(
    BuildContext context,
    dynamic c, {
    required EdgeInsetsGeometry padding,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.gradient,
        ),
        border: Border.all(color: c.border, width: 1),
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _muscleChip(BuildContext context, String label, Color accent) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 8),
        vertical: Responsive.height(context, 3),
      ),
      decoration: BoxDecoration(
        color: accent.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(60)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: accent,
          fontSize: Responsive.font(context, 10),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
