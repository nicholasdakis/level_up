import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/globals.dart';
import '/utility/responsive.dart';

class BrowseRoutinesScreen extends StatefulWidget {
  const BrowseRoutinesScreen({super.key});

  @override
  State<BrowseRoutinesScreen> createState() => _BrowseRoutinesScreenState();
}

class _BrowseRoutinesScreenState extends State<BrowseRoutinesScreen> {
  late final VoidCallback _colorListener;
  List<Map<String, dynamic>> _featured = [];
  List<Map<String, dynamic>> _community = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _colorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_colorListener);
    _fetchData();
  }

  Future<void> _fetchData() async {
    final data = await userManager.fetchBrowseRoutines();
    if (mounted) {
      setState(() {
        _featured = (data['featured'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _community = (data['community'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _loading = false;
      });
    }
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
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: accent,
                          strokeWidth: 2,
                        ),
                      )
                    : ScrollConfiguration(
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
                              _buildFeaturedRow(
                                context,
                                accent,
                                dim,
                                subtle,
                                c,
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      Responsive.centeredHorizontalPadding(
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
                              _buildCommunityList(
                                context,
                                accent,
                                dim,
                                subtle,
                                c,
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
          itemCount: _featured.length,
          separatorBuilder: (_, _) =>
              SizedBox(width: Responsive.width(context, 12)),
          itemBuilder: (context, i) =>
              _buildFeaturedCard(context, _featured[i], accent, dim, subtle, c),
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(
    BuildContext context,
    Map<String, dynamic> routine,
    Color accent,
    Color dim,
    Color subtle,
    dynamic c,
  ) {
    final exercises = (routine['exercises'] as List? ?? []);
    final exerciseCount = routine['exercise_count'] as int? ?? exercises.length;
    final duration = routine['estimated_duration_minutes'] as int?;
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
              routine['name'] as String,
              style: GoogleFonts.manrope(
                color: accent,
                fontSize: Responsive.font(context, 15),
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '$exerciseCount exercises${duration != null ? ' · $duration min' : ''}',
              style: GoogleFonts.manrope(
                color: dim,
                fontSize: Responsive.font(context, 11),
              ),
            ),
            SizedBox(height: Responsive.height(context, 8)),
            for (final ex in exercises.take(3))
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
                        ex['exercise_name'] as String,
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
            if (exercises.length > 3)
              Text(
                '+${exercises.length - 3} more',
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
    if (_community.isEmpty) return const SizedBox.shrink();
    final hPad = Responsive.centeredHorizontalPadding(context, 20);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        children: [
          for (int i = 0; i < _community.length; i++) ...[
            _buildCommunityCard(context, _community[i], accent, dim, subtle, c),
            if (i < _community.length - 1)
              SizedBox(height: Responsive.height(context, 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildCommunityCard(
    BuildContext context,
    Map<String, dynamic> routine,
    Color accent,
    Color dim,
    Color subtle,
    dynamic c,
  ) {
    final exercises = (routine['exercises'] as List? ?? []);
    final exerciseCount = routine['exercise_count'] as int? ?? exercises.length;
    final creator = routine['creator_username'] as String?;
    return _styledCard(
      context,
      c,
      padding: EdgeInsets.all(Responsive.scale(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            routine['name'] as String,
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
              if (creator != null)
                Text(
                  '@$creator',
                  style: GoogleFonts.manrope(
                    color: dim,
                    fontSize: Responsive.font(context, 11),
                  ),
                ),
              Text(
                ' · $exerciseCount exercises',
                style: GoogleFonts.manrope(
                  color: subtle,
                  fontSize: Responsive.font(context, 11),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.height(context, 8)),
          for (final ex in exercises.take(3))
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
                      ex['exercise_name'] as String,
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
          if (exercises.length > 3)
            Text(
              '+${exercises.length - 3} more',
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
}
