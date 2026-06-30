import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '/globals.dart';
import '/utility/responsive.dart';

class BrowseRoutinesScreen extends StatefulWidget {
  const BrowseRoutinesScreen({super.key});

  @override
  State<BrowseRoutinesScreen> createState() => _BrowseRoutinesScreenState();
}

class _BrowseRoutinesScreenState extends State<BrowseRoutinesScreen> {
  late final VoidCallback _colorListener;
  late final ScrollController _featuredScroll;
  List<Map<String, dynamic>> _featured = [];
  List<Map<String, dynamic>> _community = [];
  bool _loading = true;
  int _featuredIndex = 0;
  String? _savingId;
  Set<String> _savedSourceIds = {};
  // optimistic like state: maps template_id -> {liked, count}
  final Map<String, Map<String, dynamic>> _likeState = {};

  static const List<Map<String, dynamic>> _skeletonRoutines = [
    {
      'template_id': 'sk1',
      'name': 'Placeholder Routine',
      'exercise_count': 5,
      'exercises': [
        {'exercise_name': 'Exercise One'},
        {'exercise_name': 'Exercise Two'},
        {'exercise_name': 'Exercise Three'},
      ],
      'estimated_duration_minutes': 30,
      'like_count': 0,
      'liked_by_me': false,
    },
    {
      'template_id': 'sk2',
      'name': 'Placeholder Routine',
      'exercise_count': 4,
      'exercises': [
        {'exercise_name': 'Exercise One'},
        {'exercise_name': 'Exercise Two'},
        {'exercise_name': 'Exercise Three'},
      ],
      'estimated_duration_minutes': 45,
      'like_count': 0,
      'liked_by_me': false,
    },
    {
      'template_id': 'sk3',
      'name': 'Placeholder Routine',
      'exercise_count': 6,
      'exercises': [
        {'exercise_name': 'Exercise One'},
        {'exercise_name': 'Exercise Two'},
        {'exercise_name': 'Exercise Three'},
      ],
      'estimated_duration_minutes': 60,
      'like_count': 0,
      'liked_by_me': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _colorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_colorListener);
    _featuredScroll = ScrollController();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final results = await Future.wait([
      userManager.fetchBrowseRoutines(),
      userManager.fetchMyRoutines(),
    ]);
    final data = results[0] as Map<String, dynamic>;
    final myRoutines = results[1] as List<Map<String, dynamic>>;
    if (mounted) {
      setState(() {
        _featured = (data['featured'] as List)
            .map((routine) => Map<String, dynamic>.from(routine as Map))
            .toList();
        _community = (data['community'] as List)
            .map((routine) => Map<String, dynamic>.from(routine as Map))
            .toList();
        // track which browse templates the user already copied to block duplicates
        _savedSourceIds = myRoutines
            .map((routine) => routine['source_template_id'] as String?)
            .whereType<String>()
            .toSet();
        // build optimistic like state from the server response
        for (final r in _featured + _community) {
          _likeState[r['template_id'] as String] = {
            'liked': r['liked_by_me'] as bool? ?? false,
            'count': r['like_count'] as int? ?? 0,
          };
        }
        _loading = false;
      });
      // update dot indicator as user scrolls
      _featuredScroll.addListener(() {
        if (_featured.isEmpty || !_featuredScroll.hasClients) return;
        final maxScroll = _featuredScroll.position.maxScrollExtent;
        final offset = _featuredScroll.offset;
        // map scroll position linearly across all cards
        final index = maxScroll == 0
            ? 0
            : ((offset / maxScroll) * (_featured.length - 1)).round().clamp(
                0,
                _featured.length - 1,
              );
        if (index != _featuredIndex) setState(() => _featuredIndex = index);
      });
    }
  }

  Future<void> _copyRoutine(String templateId) async {
    if (_savingId != null) return;
    if (_savedSourceIds.contains(templateId)) {
      // already copied this template
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You already have this routine saved',
            style: GoogleFonts.manrope(),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _savingId = templateId);
    final ok = await userManager.copyRoutine(templateId: templateId);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _savingId = null;
        _savedSourceIds.add(
          templateId,
        ); // prevent duplicate saves without refetching
      });
      workoutLogNotifier.value++;
    } else {
      setState(() => _savingId = null);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Routine saved to My Routines' : 'Failed to save routine',
          style: GoogleFonts.manrope(),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleLike(String templateId) async {
    final current = _likeState[templateId] ?? {'liked': false, 'count': 0};
    final wasLiked = current['liked'] as bool;
    // optimistic update
    setState(() {
      _likeState[templateId] = {
        'liked': !wasLiked,
        'count': (current['count'] as int) + (wasLiked ? -1 : 1),
      };
    });
    final ok = wasLiked
        ? await userManager.unlikeRoutine(templateId: templateId)
        : await userManager.likeRoutine(templateId: templateId);
    if (!mounted) return;
    if (!ok) {
      // revert on failure
      setState(() => _likeState[templateId] = current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Couldn\'t save like, try again.',
            style: GoogleFonts.manrope(),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    appColorNotifier.removeListener(_colorListener);
    _featuredScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColor = appColorNotifier.value;
    final c = cardColors(appColor);
    final accent = c.onCard;
    final dim = c.onCard.withAlpha(180);
    final subtle = c.onCard.withAlpha(120);

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // back button only, no title
              Padding(
                padding: EdgeInsets.only(
                  left: Responsive.centeredHorizontalPadding(context, 20),
                  top: Responsive.height(context, 12),
                  bottom: Responsive.height(context, 4),
                ),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: EdgeInsets.all(Responsive.scale(context, 10)),
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
              Expanded(
                child: Skeletonizer(
                  enabled: _loading,
                  effect: ShimmerEffect(
                    baseColor: lightenColor(appColorNotifier.value, 0.3),
                    highlightColor: lightenColor(appColorNotifier.value, 0.1),
                    duration: const Duration(milliseconds: 1200),
                  ),
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
                              top: Responsive.height(context, 8),
                              bottom: Responsive.height(context, 12),
                            ),
                          ),
                          _buildFeaturedRow(context, accent, dim, subtle, c),
                          SizedBox(height: Responsive.height(context, 10)),
                          // dot indicator showing current featured card position
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _loading ? 3 : _featured.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutQuart,
                                margin: EdgeInsets.symmetric(
                                  horizontal: Responsive.width(context, 3),
                                ),
                                width: Responsive.scale(
                                  context,
                                  i == _featuredIndex ? 18 : 6,
                                ),
                                height: Responsive.scale(context, 6),
                                decoration: BoxDecoration(
                                  color: i == _featuredIndex
                                      ? accent
                                      : accent.withAlpha(60),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 20)),
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
              ),
            ],
          ),
        ),
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
    final cardHeight = Responsive.height(context, 220);
    final items = _loading ? _skeletonRoutines : _featured;
    return SizedBox(
      height: cardHeight,
      child: ScrollConfiguration(
        behavior: NoGlowScrollBehavior().copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: ListView.separated(
          controller: _featuredScroll,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: hPad),
          itemCount: items.length,
          separatorBuilder: (_, _) =>
              SizedBox(width: Responsive.width(context, 12)),
          itemBuilder: (context, i) => _buildFeaturedCard(
            context,
            items[i],
            accent,
            dim,
            subtle,
            c,
            cardHeight,
          ),
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
    double height,
  ) {
    final exercises = (routine['exercises'] as List? ?? []);
    final exerciseCount = routine['exercise_count'] as int? ?? exercises.length;
    final duration = routine['estimated_duration_minutes'] as int?;
    return SizedBox(
      width: Responsive.width(context, 200),
      height: height,
      child: _styledCard(
        context,
        c,
        padding: EdgeInsets.all(Responsive.scale(context, 14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxHeight: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 7),
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
                                size: Responsive.scale(context, 9),
                              ),
                              SizedBox(width: Responsive.width(context, 3)),
                              Text(
                                'FEATURED',
                                style: GoogleFonts.manrope(
                                  color: accent,
                                  fontSize: Responsive.font(context, 8),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    SizedBox(height: Responsive.height(context, 10)),
                    Text(
                      routine['name'] as String,
                      style: GoogleFonts.manrope(
                        color: accent,
                        fontSize: Responsive.font(context, 14),
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$exerciseCount exercises${duration != null ? ' · $duration min' : ''}',
                      style: GoogleFonts.manrope(
                        color: dim,
                        fontSize: Responsive.font(context, 10),
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 10)),
                    for (final ex in exercises.take(3))
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 3),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: dim.withAlpha(100),
                              size: Responsive.scale(context, 4),
                            ),
                            SizedBox(width: Responsive.width(context, 5)),
                            Expanded(
                              child: Text(
                                ex['exercise_name'] as String,
                                style: GoogleFonts.manrope(
                                  color: dim,
                                  fontSize: Responsive.font(context, 10),
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
                          fontSize: Responsive.font(context, 9),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: Responsive.height(context, 8)),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(routine['template_id'] as String),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedFavourite,
                        color:
                            (_likeState[routine['template_id']]?['liked']
                                    as bool? ??
                                false)
                            ? accent
                            : subtle,
                        size: Responsive.scale(context, 13),
                      ),
                      SizedBox(width: Responsive.width(context, 3)),
                      Text(
                        '${_likeState[routine['template_id']]?['count'] ?? 0}',
                        style: GoogleFonts.manrope(
                          color: subtle,
                          fontSize: Responsive.font(context, 10),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.height(context, 8)),
            GestureDetector(
              onTap: _savingId == null
                  ? () => _copyRoutine(routine['template_id'] as String)
                  : null,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.height(context, 10),
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
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedBookmark02,
                      color: accent,
                      size: Responsive.scale(context, 13),
                    ),
                    SizedBox(width: Responsive.width(context, 5)),
                    Text(
                      'Save This Routine',
                      style: GoogleFonts.manrope(
                        color: accent,
                        fontSize: Responsive.font(context, 11),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
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
    final items = _loading ? _skeletonRoutines : _community;
    if (!_loading && items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: hPad,
          vertical: Responsive.height(context, 20),
        ),
        child: _styledCard(
          context,
          c,
          padding: EdgeInsets.all(Responsive.scale(context, 20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedUserGroup,
                color: subtle,
                size: Responsive.scale(context, 32),
              ),
              SizedBox(height: Responsive.height(context, 10)),
              Text(
                'No community routines yet',
                style: GoogleFonts.manrope(
                  color: accent,
                  fontSize: Responsive.font(context, 13),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: Responsive.height(context, 4)),
              Text(
                'Be the first to share a routine',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: dim,
                  fontSize: Responsive.font(context, 11),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildCommunityCard(context, items[i], accent, dim, subtle, c),
            if (i < items.length - 1)
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
              padding: EdgeInsets.only(bottom: Responsive.height(context, 3)),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    color: dim.withAlpha(100),
                    size: Responsive.scale(context, 4),
                  ),
                  SizedBox(width: Responsive.width(context, 5)),
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
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleLike(routine['template_id'] as String),
                child: Row(
                  children: [
                    HugeIcon(
                      icon:
                          (_likeState[routine['template_id']]?['liked']
                                  as bool? ??
                              false)
                          ? HugeIcons.strokeRoundedFavourite
                          : HugeIcons.strokeRoundedFavourite,
                      color:
                          (_likeState[routine['template_id']]?['liked']
                                  as bool? ??
                              false)
                          ? accent
                          : subtle,
                      size: Responsive.scale(context, 15),
                    ),
                    SizedBox(width: Responsive.width(context, 4)),
                    Text(
                      '${_likeState[routine['template_id']]?['count'] ?? 0}',
                      style: GoogleFonts.manrope(
                        color: subtle,
                        fontSize: Responsive.font(context, 11),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
          SizedBox(height: Responsive.height(context, 8)),
          GestureDetector(
            onTap: _savingId == null
                ? () => _copyRoutine(routine['template_id'] as String)
                : null,
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
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedBookmark02,
                    color: accent,
                    size: Responsive.scale(context, 15),
                  ),
                  SizedBox(width: Responsive.width(context, 6)),
                  Text(
                    'Save This Routine',
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
