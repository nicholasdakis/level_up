import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../globals.dart';
import '../providers/user_data_provider.dart';
import '../services/premium_service.dart';
import '../services/user_data_manager.dart' show defaultAppColor;
import '../utility/responsive.dart';
import '../utility/confetti.dart';
import 'pro_welcome_overlay.dart';

Future<void> showPremiumSheet(BuildContext context, WidgetRef ref) async {
  final existingPreview = premiumPreviewNotifier.value;
  premiumPreviewNotifier.value = null;
  final originalColor = ref.read(userDataProvider).value?.appColor;
  // Notifier lets the sheet pass back whatever color was previewed on close
  final previewedColor = ValueNotifier<Color?>(null);

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(160),
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => _PremiumSheet(previewedColor: previewedColor),
  );

  if (originalColor == null) return;
  final isPremiumNow = ref.read(userDataProvider).value?.isPremium ?? false;
  if (isPremiumNow) return;

  final picked = previewedColor.value;
  if (picked != null && picked.toARGB32() != originalColor.toARGB32()) {
    // Apply the preview color to the provider once, then start the countdown
    ref
        .read(userDataProvider.notifier)
        .patch((u) => u.copyWith(appColor: picked));
    premiumPreviewNotifier.value = (
      originalColor: originalColor,
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
    );
  } else if (picked == null &&
      existingPreview != null &&
      existingPreview.expiresAt.isAfter(DateTime.now())) {
    // User closed without picking a new color, restore the previous countdown
    premiumPreviewNotifier.value = existingPreview;
  }
}

// Fake leaderboard data for the preview
const _fakeLeaderboard = [
  (name: 'You', isPro: true, rank: 1, level: 28, xp: 3200, xpNeeded: 4100),
  (
    name: 'SteelMind',
    isPro: true,
    rank: 2,
    level: 26,
    xp: 2800,
    xpNeeded: 3800,
  ),
  (
    name: 'IronWill',
    isPro: false,
    rank: 3,
    level: 24,
    xp: 1900,
    xpNeeded: 3500,
  ),
  (name: 'FitQuest', isPro: false, rank: 4, level: 22, xp: 900, xpNeeded: 3200),
];

// Theme color options for the preview
const _themeColors = [
  (color: Color(0xFF6C63FF), name: 'Purple'),
  (color: Color(0xFFE74C3C), name: 'Red'),
  (color: Color(0xFF2ECC71), name: 'Green'),
  (color: Color(0xFFE67E22), name: 'Orange'),
  (color: Color(0xFF1ABC9C), name: 'Teal'),
  (color: Color(0xFFE91E8C), name: 'Pink'),
];

class _PremiumSheet extends ConsumerStatefulWidget {
  final ValueNotifier<Color?> previewedColor;
  const _PremiumSheet({required this.previewedColor});

  @override
  ConsumerState<_PremiumSheet> createState() => _PremiumSheetState();
}

class _PremiumSheetState extends ConsumerState<_PremiumSheet>
    with TickerProviderStateMixin {
  // Base color read once from the provider, never watched, so patching the provider does not rebuild this sheet
  Color _baseColor = defaultAppColor;
  // Local preview color set by tapping swatches; never triggers a provider rebuild
  Color? _previewColor;
  // Actual color used throughout the sheet
  Color get appColor => _previewColor ?? _baseColor;

  String get username =>
      ref.watch(userDataProvider.select((s) => s.value?.username ?? 'You'));
  int get _dailyStreak =>
      ref.read(userDataProvider).value?.dailyClaimStreak ?? 0;
  int get _level => ref.read(userDataProvider).value?.level ?? 1;

  List<ProductDetails> _products = [];
  bool _loading = true;
  bool _loadFailed = false;
  bool _purchasing = false;
  String _selectedId = 'level_up_premium:yearly';
  Color? _originalColor;

  late final AnimationController _shimmerController;
  late final AnimationController _pulseController;
  late final AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    logAnalyticsEvent('premium_sheet_opened');
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    // Particles run at 20s so they repaint infrequently and don't block the main thread
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _loadProducts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final providerColor = ref.read(userDataProvider).value?.appColor;
    if (providerColor != null) {
      _originalColor ??= providerColor;
      _baseColor = providerColor;
    }
  }

  @override
  void dispose() {
    if (!_purchasing) logAnalyticsEvent('premium_sheet_dismissed');
    _shimmerController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final service = ref.read(premiumServiceProvider);
    final products = await service.loadProducts().timeout(
      const Duration(seconds: 10),
      onTimeout: () => [],
    );
    if (!mounted) return;
    // Sort by price descending so yearly is first
    products.sort((a, b) => b.rawPrice.compareTo(a.rawPrice));
    setState(() {
      _products = products;
      _loading = false;
      _loadFailed = products.isEmpty;
    });
  }

  // yearly = index 0 (sorted by price desc), monthly = index 1
  ProductDetails? get _yearly => _products.isNotEmpty ? _products[0] : null;
  ProductDetails? get _monthly => _products.length > 1 ? _products[1] : null;

  ProductDetails? get _selectedProduct {
    if (_selectedId.contains('monthly')) return _monthly;
    return _yearly;
  }

  Future<void> _subscribe() async {
    final product = _selectedProduct;
    debugPrint(
      '_subscribe called, product=${product?.id}, purchasing=$_purchasing',
    );
    if (product == null || _purchasing) return;
    setState(() => _purchasing = true);
    logAnalyticsEvent(
      'premium_subscribe_tapped',
      parameters: {'product_id': product.id},
    );
    try {
      await ref.read(premiumServiceProvider).subscribe(product);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Purchase failed. Try again.',
              style: GoogleFonts.manrope(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  // Shimmer gradient text
  Widget _shimmerText(
    String text,
    double fontSize, {
    FontWeight weight = FontWeight.w900,
    double letterSpacing = 2,
  }) {
    return ShimmerWidget(
      accent: lightenColor(appColor, 0.45),
      colors: [
        lightenColor(appColor, 0.3),
        lightenColor(appColor, 0.45),
        Colors.white,
        lightenColor(appColor, 0.45),
        lightenColor(appColor, 0.3),
      ],
      animation: _shimmerController,
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: fontSize,
          fontWeight: weight,
          color: Colors.white,
          letterSpacing: letterSpacing,
        ),
      ),
    );
  }

  // Leaderboard preview styled like the real leaderboard tab
  Widget _buildLeaderboardPreview(Color accent, Color dim) {
    final displayUsername = username;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: Responsive.scale(context, 3),
              height: Responsive.scale(context, 18),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: Responsive.width(context, 8)),
            Text(
              'LEADERBOARD PREVIEW',
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 11),
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.height(context, 6)),
        Text(
          'Pro members stand out with a shimmering name and badge',
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 12),
            color: dim,
          ),
        ),
        SizedBox(height: Responsive.height(context, 12)),
        for (final entry in _fakeLeaderboard) ...[
          _buildLeaderboardCard(
            name: entry.name == 'You' ? displayUsername : entry.name,
            isPro: entry.isPro,
            rank: entry.rank,
            level: entry.level,
            xp: entry.xp,
            xpNeeded: entry.xpNeeded,
            isCurrentUser: entry.name == 'You',
            accent: accent,
            dim: dim,
          ),
          SizedBox(height: Responsive.height(context, 6)),
        ],
      ],
    );
  }

  Widget _buildLeaderboardCard({
    required String name,
    required bool isPro,
    required int rank,
    required int level,
    required int xp,
    required int xpNeeded,
    required bool isCurrentUser,
    required Color accent,
    required Color dim,
  }) {
    Color rankColor() {
      if (rank == 1) return Colors.yellow;
      if (rank == 2) return const Color(0xFFB0B8C1);
      if (rank == 3) return const Color(0xFFCD7F32);
      return cardColors(appColor).onCard;
    }

    Widget? rankMedal() {
      if (rank > 3) return null;
      return HugeIcon(
        icon: HugeIcons.strokeRoundedMedal01,
        color: rankColor(),
        size: Responsive.scale(context, 16),
      );
    }

    final fraction = (xp / xpNeeded).clamp(0.0, 1.0);

    Widget nameWidget;
    if (isPro) {
      nameWidget = ShimmerWidget(
        accent: lightenColor(appColor, 0.45),
        colors: [
          lightenColor(appColor, 0.3),
          lightenColor(appColor, 0.45),
          Colors.white,
          lightenColor(appColor, 0.45),
          lightenColor(appColor, 0.3),
        ],
        animation: _shimmerController,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 14),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(width: Responsive.width(context, 5)),
            proChip(context, animation: _shimmerController),
          ],
        ),
      );
    } else {
      nameWidget = Text(
        name,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 14),
          color: cardColors(appColor).onCard,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 14),
        vertical: Responsive.height(context, 10),
      ),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? lightenColor(appColor, 0.12).withAlpha(220)
            : Colors.black.withAlpha(60),
        borderRadius: BorderRadius.circular(Responsive.scale(context, 14)),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFFFFD700).withAlpha(180)
              : cardColors(appColor).border,
          width: isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Rank
              if (rankMedal() != null)
                Row(
                  children: [
                    Text(
                      '#$rank',
                      style: GoogleFonts.manrope(
                        color: rankColor(),
                        fontSize: Responsive.font(context, 14),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: Responsive.width(context, 6)),
                    rankMedal()!,
                    SizedBox(width: Responsive.width(context, 6)),
                  ],
                )
              else
                SizedBox(
                  width: Responsive.width(context, 36),
                  child: Text(
                    '#$rank',
                    style: GoogleFonts.manrope(
                      color: rankColor(),
                      fontSize: Responsive.font(context, 13),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // Avatar placeholder
              Container(
                width: Responsive.scale(context, 32),
                height: Responsive.scale(context, 32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: appColor.withAlpha(80),
                  border: Border.all(color: accent.withAlpha(60), width: 1),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedUser02,
                  color: accent,
                  size: Responsive.scale(context, 18),
                ),
              ),
              SizedBox(width: Responsive.width(context, 10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    nameWidget,
                    Text(
                      'Level $level',
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 11),
                        color: cardColors(appColor).onCard.withAlpha(100),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$xp / $xpNeeded XP',
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 11),
                  color: cardColors(appColor).onCard,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.height(context, 6)),
          // XP progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 4)),
            child: Stack(
              children: [
                Container(
                  height: Responsive.height(context, 4),
                  color: Colors.white.withAlpha(18),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: Responsive.height(context, 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          lightenColor(appColor, 0.3).withAlpha(180),
                          lightenColor(appColor, 0.45),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _previewThemeColor(Color color) {
    logAnalyticsEvent('premium_color_previewed');
    if (color.computeLuminance() > 0.5) {
      final excess = (color.computeLuminance() - 0.5) * 0.8;
      color = darkenColor(color, math.max(excess, 0.15));
    }
    setState(() => _previewColor = color);
    widget.previewedColor.value = color;
    ref
        .read(userDataProvider.notifier)
        .patch((u) => u.copyWith(appColor: color));
  }

  void _showCustomColorPicker() {
    Color pickerColor = appColor;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
        insetPadding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 24),
          vertical: Responsive.height(context, 40),
        ),
        child: IntrinsicWidth(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 20),
                  ),
                  border: Border.all(
                    color: Colors.white.withAlpha(22),
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 28),
                  vertical: Responsive.height(context, 32),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pick any color',
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 15),
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 16)),
                    ColorPicker(
                      pickerColor: pickerColor,
                      onColorChanged: (c) => pickerColor = c,
                      colorPickerWidth: 280,
                      labelTypes: const [],
                      enableAlpha: false,
                      pickerAreaHeightPercent: 0.8,
                    ),
                    SizedBox(height: Responsive.height(context, 8)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.manrope(color: Colors.white54),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _previewThemeColor(pickerColor);
                          },
                          child: Text(
                            'Preview',
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

  // Theme color preview: patches the provider so the whole sheet re-renders in that color
  Widget _buildThemePreview(Color accent, Color dim) {
    final isPreviewingAny = _previewColor != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: Responsive.scale(context, 3),
              height: Responsive.scale(context, 18),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: Responsive.width(context, 8)),
            Text(
              'EXCLUSIVE THEMES',
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 11),
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.height(context, 6)),
        Text(
          'Tap a preset or pick any color to preview the whole app',
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 12),
            color: dim,
          ),
        ),
        SizedBox(height: Responsive.height(context, 14)),
        // Live color bar: reflects current appColor which changes on tap
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: Responsive.height(context, 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                lightenColor(appColor, 0.2),
                lightenColor(appColor, 0.45),
              ],
            ),
            borderRadius: BorderRadius.circular(Responsive.scale(context, 6)),
            boxShadow: [
              BoxShadow(
                color: appColor.withAlpha(100),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        SizedBox(height: Responsive.height(context, 14)),
        // Color swatches + custom picker
        Row(
          children: [
            for (final theme in _themeColors)
              Expanded(
                child: GestureDetector(
                  onTap: () => _previewThemeColor(theme.color),
                  child: Builder(
                    builder: (ctx) {
                      final isSelected =
                          appColor.toARGB32() == theme.color.toARGB32();
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: EdgeInsets.symmetric(
                          horizontal: Responsive.width(ctx, 4),
                        ),
                        height: Responsive.scale(ctx, isSelected ? 44 : 36),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.color,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: theme.color.withAlpha(140),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withAlpha(40),
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: Colors.white,
                                size: Responsive.scale(ctx, 16),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ),
            // Custom color swatch
            Expanded(
              child: GestureDetector(
                onTap: _showCustomColorPicker,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 4),
                  ),
                  height: Responsive.scale(context, 36),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(15),
                    border: Border.all(
                      color: Colors.white.withAlpha(60),
                      width: 1,
                    ),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedAdd01,
                    color: onTheme(appColor),
                    size: Responsive.scale(context, 16),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (isPreviewingAny) ...[
          SizedBox(height: Responsive.height(context, 12)),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 16),
                vertical: Responsive.height(context, 14),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: cardColors(appColor).gradient),
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 12),
                ),
                border: Border.all(
                  color: cardColors(appColor).border,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    color: cardColors(appColor).onCard,
                    size: Responsive.scale(context, 17),
                  ),
                  SizedBox(width: Responsive.width(context, 8)),
                  Text(
                    'Tap to try this color in the app.',
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 14),
                      color: cardColors(appColor).onCard,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Free vs Pro comparison
  Widget _buildComparison(Color accent, Color dim) {
    final onCard = cardColors(appColor).onCard;

    // (title, outcome subtitle, freeLabel, proLabel)
    // freeLabel null = pro exclusive
    final upgradeRows = [
      (
        'Full Progress History',
        'See your entire health journey',
        '14 days',
        'Unlimited',
      ),
      (
        'Extended Quick Logging',
        'Every food you\'ve tracked, always accessible',
        '20 foods',
        '500 foods',
      ),
      (
        'Unlimited Themes',
        'Make the app truly yours',
        '15 presets',
        'Unlimited',
      ),
    ];
    final proRows = [
      ('1.2× XP Multiplier', 'Earn 20% more XP on every action'),
      ('Streak Shields', 'Protect your streak on off days'),
      ('Shimmering Pro Badge', 'Stand out on the leaderboard'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: Responsive.scale(context, 3),
              height: Responsive.scale(context, 18),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: Responsive.width(context, 8)),
            Text(
              'WHAT YOU UNLOCK',
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 11),
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.height(context, 12)),

        // Upgrade rows: each shows free cap vs pro value
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(40),
            borderRadius: BorderRadius.circular(Responsive.scale(context, 14)),
            border: Border.all(color: accent.withAlpha(220), width: 2),
          ),
          child: Column(
            children: upgradeRows.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              return Column(
                children: [
                  if (i > 0)
                    Divider(
                      color: Colors.white.withAlpha(80),
                      height: 1,
                      thickness: 1.5,
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.width(context, 16),
                      vertical: Responsive.height(context, 14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.$1,
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 14),
                                  color: onCard,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: Responsive.height(context, 3)),
                              Text(
                                r.$2,
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 11),
                                  color: onCard.withAlpha(120),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: Responsive.width(context, 12)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Free',
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 9),
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: Responsive.height(context, 3)),
                                Text(
                                  r.$3,
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 12),
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: accent.withAlpha(120),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 8),
                              ),
                              child: Text(
                                '→',
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 12),
                                  color: accent.withAlpha(120),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Pro',
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 9),
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: Responsive.height(context, 3)),
                                _shimmerText(
                                  r.$4,
                                  Responsive.font(context, 12),
                                  weight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        SizedBox(height: Responsive.height(context, 10)),

        // Pro exclusive card, visually elevated
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(40),
            borderRadius: BorderRadius.circular(Responsive.scale(context, 14)),
            border: Border.all(color: accent.withAlpha(220), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.width(context, 14),
                  Responsive.height(context, 10),
                  Responsive.width(context, 14),
                  Responsive.height(context, 8),
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCrown,
                      color: accent,
                      size: Responsive.scale(context, 13),
                    ),
                    SizedBox(width: Responsive.width(context, 6)),
                    Text(
                      'Pro exclusives',
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 11),
                        color: accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                color: Colors.white.withAlpha(80),
                height: 1,
                thickness: 1.5,
              ),
              ...proRows.asMap().entries.map((e) {
                final i = e.key;
                final r = e.value;
                return Column(
                  children: [
                    if (i > 0)
                      Divider(
                        color: Colors.white.withAlpha(80),
                        height: 1,
                        thickness: 1.5,
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 16),
                        vertical: Responsive.height(context, 13),
                      ),
                      child: Row(
                        children: [
                          ShimmerWidget(
                            accent: lightenColor(appColor, 0.45),
                            colors: [
                              lightenColor(appColor, 0.30),
                              lightenColor(appColor, 0.45),
                              lightenColor(appColor, 0.30),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                            animation: _shimmerController,
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedCrown,
                              color: Colors.white,
                              size: Responsive.scale(context, 14),
                            ),
                          ),
                          SizedBox(width: Responsive.width(context, 10)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  r.$1,
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 14),
                                    color: onCard,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: Responsive.height(context, 2)),
                                Text(
                                  r.$2,
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 11),
                                    color: onCard.withAlpha(120),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _trustSignal(IconData icon, String label, Color dim) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, color: dim, size: Responsive.scale(context, 12)),
        SizedBox(width: Responsive.width(context, 4)),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 10),
            color: dim,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = onTheme(appColor);
    final dim = onTheme(appColor);
    final hPad = Responsive.width(context, 20);

    ref.listen(userDataProvider.select((s) => s.value?.isPremium ?? false), (
      _,
      isPremium,
    ) {
      if (isPremium && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showProWelcomeOverlay(context, appColor);
      }
    });

    final yearly = _yearly;
    final monthly = _monthly;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.94,
      child: Container(
        decoration: BoxDecoration(
          gradient: buildThemeGradient(appColor),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Responsive.scale(context, 24)),
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: Responsive.height(context, 12)),
                Container(
                  width: Responsive.width(context, 40),
                  height: Responsive.height(context, 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(60),
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 4),
                    ),
                  ),
                ),
                SizedBox(height: Responsive.height(context, 28)),

                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.white],
                      stops: [0.0, 0.06],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero header with particles overlaid so they don't consume vertical space
                          Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              IgnorePointer(
                                child: ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.white,
                                          Colors.white,
                                        ],
                                        stops: [0.0, 0.35, 1.0],
                                      ).createShader(bounds),
                                  blendMode: BlendMode.dstIn,
                                  child: AnimatedBuilder(
                                    animation: _particleController,
                                    builder: (_, _) => CustomPaint(
                                      painter: _ParticlePainter(
                                        progress: _particleController.value,
                                        color: accent,
                                      ),
                                      size: Size(
                                        double.infinity,
                                        Responsive.height(context, 180),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Center(
                                child: Column(
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (_, _) => Padding(
                                        // Extra padding so the pulsing shadow is never clipped
                                        padding: EdgeInsets.all(
                                          Responsive.scale(context, 14),
                                        ),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: accent.withAlpha(180),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: accent.withAlpha(
                                                  (50 +
                                                          60 *
                                                              _pulseController
                                                                  .value)
                                                      .toInt(),
                                                ),
                                                blurRadius:
                                                    18 +
                                                    14 * _pulseController.value,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: SizedBox(
                                              width: Responsive.scale(
                                                context,
                                                64,
                                              ),
                                              height: Responsive.scale(
                                                context,
                                                64,
                                              ),
                                              child: Image.asset(
                                                'assets/app_logo_circle.png',
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    HugeIcon(
                                                      icon: HugeIcons
                                                          .strokeRoundedCrown,
                                                      color: accent,
                                                      size: Responsive.scale(
                                                        context,
                                                        30,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: Responsive.height(context, 14),
                                    ),
                                    _shimmerText(
                                      'LEVEL UP! PRO',
                                      Responsive.font(context, 24),
                                    ),
                                    SizedBox(
                                      height: Responsive.height(context, 6),
                                    ),
                                    Text(
                                      _dailyStreak > 1
                                          ? 'Your daily streak is at $_dailyStreak days. Go Pro and a shield will protect it if you miss a day.'
                                          : 'Level $_level and climbing. Save over 50% with the yearly plan.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(context, 13),
                                        color: dim,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: Responsive.height(context, 28)),

                          // Leaderboard preview
                          _buildLeaderboardPreview(accent, dim)
                              .animate()
                              .slideY(
                                begin: 0.15,
                                end: 0,
                                duration: 400.ms,
                                curve: Curves.easeOutCubic,
                              )
                              .fadeIn(duration: 400.ms),

                          SizedBox(height: Responsive.height(context, 24)),

                          // Theme preview
                          _buildThemePreview(accent, dim)
                              .animate()
                              .slideY(
                                begin: 0.15,
                                end: 0,
                                delay: 100.ms,
                                duration: 400.ms,
                                curve: Curves.easeOutCubic,
                              )
                              .fadeIn(delay: 100.ms, duration: 400.ms),

                          SizedBox(height: Responsive.height(context, 24)),

                          // Free vs Pro
                          _buildComparison(accent, dim)
                              .animate()
                              .slideY(
                                begin: 0.15,
                                end: 0,
                                delay: 200.ms,
                                duration: 400.ms,
                                curve: Curves.easeOutCubic,
                              )
                              .fadeIn(delay: 200.ms, duration: 400.ms),

                          SizedBox(height: Responsive.height(context, 24)),

                          // Plan selector
                          if (_loading && !kIsWeb) ...[
                            _SkeletonTile(appColor: appColor, tall: true),
                            SizedBox(height: Responsive.height(context, 10)),
                            _SkeletonTile(appColor: appColor, tall: false),
                          ] else if (_loadFailed && !kIsWeb) ...[
                            Text(
                              'Could not load pricing. Check your connection and try again.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 13),
                                color: onTheme(appColor),
                              ),
                            ),
                            SizedBox(height: Responsive.height(context, 12)),
                            frostedButton(
                              'Retry',
                              context,
                              color: appColor,
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _loadFailed = false;
                                });
                                _loadProducts();
                              },
                            ),
                          ] else ...[
                            _PlanTile(
                              label: 'Yearly',
                              subtitle: '\$2.50/mo. Save over 50% vs monthly.',
                              price: kIsWeb ? '\$29.99 / yr' : yearly!.price,
                              badge: '50% OFF',
                              selected: !_selectedId.contains('monthly'),
                              large: true,
                              appColor: appColor,
                              onTap: () {
                                logAnalyticsEvent(
                                  'premium_plan_selected',
                                  parameters: {'plan': 'yearly'},
                                );
                                setState(
                                  () => _selectedId = 'level_up_premium:yearly',
                                );
                              },
                            ),
                            SizedBox(height: Responsive.height(context, 10)),
                            _PlanTile(
                              label: 'Monthly',
                              subtitle: 'Billed every month',
                              price: kIsWeb ? '\$4.99 / mo' : monthly!.price,
                              badge: null,
                              selected: _selectedId.contains('monthly'),
                              large: false,
                              appColor: appColor,
                              onTap: () {
                                logAnalyticsEvent(
                                  'premium_plan_selected',
                                  parameters: {'plan': 'monthly'},
                                );
                                setState(
                                  () =>
                                      _selectedId = 'level_up_premium:monthly',
                                );
                              },
                            ),
                          ],

                          SizedBox(height: Responsive.height(context, 16)),
                        ],
                      ),
                    ),
                  ),
                ),

                // CTA
                Divider(color: Colors.white.withAlpha(80), height: 1),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    hPad,
                    Responsive.height(context, 14),
                    hPad,
                    Responsive.height(context, 16) +
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    children: [
                      // Competitor callout
                      if (!_loading && !_purchasing)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: Responsive.height(context, 10),
                          ),
                          child: Builder(
                            builder: (context) {
                              final isYearly = _selectedId.contains('yearly');
                              final price = isYearly
                                  ? yearly?.price
                                  : monthly?.price;
                              if (price == null) return const SizedBox.shrink();
                              final suffix = isYearly
                                  ? '$price/yr'
                                  : '$price/mo';
                              return Text(
                                'Other fitness apps charge \$20+/mo. You pay $suffix, over 87% less.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 11),
                                  color: dim,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            },
                          ),
                        ),

                      GestureDetector(
                        onTap: _purchasing
                            ? null
                            : () {
                                debugPrint(
                                  'subscribe button tapped, purchasing=$_purchasing',
                                );
                                if (kIsWeb) {
                                  showFrostedAlertDialog(
                                    context: context,
                                    appColor: appColor,
                                    title: 'Subscribe on mobile',
                                    content: Text(
                                      'Download the Level Up! app on Android to subscribe and unlock Pro.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        color: Colors.white70,
                                        fontSize: Responsive.font(context, 13),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: Text(
                                          'Got it',
                                          style: dialogButtonStyle(
                                            confirm: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  _subscribe();
                                }
                              },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: Responsive.height(context, 17),
                          ),
                          decoration: BoxDecoration(
                            gradient: _purchasing
                                ? LinearGradient(
                                    colors: [
                                      appColor.withAlpha(80),
                                      appColor.withAlpha(80),
                                    ],
                                  )
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      appColor.withAlpha(160),
                                      lightenColor(
                                        appColor,
                                        0.08,
                                      ).withAlpha(140),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 14),
                            ),
                            border: Border.all(
                              color: accent.withAlpha(220),
                              width: 2,
                            ),
                            boxShadow: _purchasing
                                ? []
                                : [
                                    BoxShadow(
                                      color: accent.withAlpha(80),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                    BoxShadow(
                                      color: accent.withAlpha(30),
                                      blurRadius: 40,
                                      spreadRadius: 4,
                                    ),
                                  ],
                          ),
                          child: _purchasing
                              ? Center(
                                  child: SizedBox(
                                    width: Responsive.scale(context, 20),
                                    height: Responsive.scale(context, 20),
                                    child: CircularProgressIndicator(
                                      color: accent,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    Text(
                                      'Unlock Pro Status',
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(context, 16),
                                        color: accent,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    if (_selectedProduct != null) ...[
                                      SizedBox(
                                        height: Responsive.height(context, 3),
                                      ),
                                      Text(
                                        _selectedId.contains('yearly')
                                            ? '${_selectedProduct!.price} / year · less than \$2.50/mo'
                                            : '${_selectedProduct!.price} / month',
                                        style: GoogleFonts.manrope(
                                          fontSize: Responsive.font(
                                            context,
                                            11,
                                          ),
                                          color: accent,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 10)),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: Responsive.width(context, 16),
                        runSpacing: Responsive.height(context, 6),
                        children: [
                          _trustSignal(
                            HugeIcons.strokeRoundedLock,
                            'Secure billing',
                            dim,
                          ),
                          _trustSignal(
                            HugeIcons.strokeRoundedLaptop,
                            'Cross-platform carryover',
                            dim,
                          ),
                          _trustSignal(
                            HugeIcons.strokeRoundedRefresh,
                            'Restore purchase',
                            dim,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Align(
              alignment: Alignment.topCenter,
              child: buildDailyRewardConfetti(badgesConfettiController),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  final Color appColor;
  final bool tall;

  const _SkeletonTile({required this.appColor, required this.tall});

  @override
  Widget build(BuildContext context) {
    final shimmer = Colors.white.withAlpha(18);
    final radius = BorderRadius.circular(Responsive.scale(context, 14));
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 18),
        vertical: Responsive.height(context, tall ? 18 : 14),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withAlpha(20), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: Responsive.height(context, 14),
                  width: Responsive.width(context, 80),
                  decoration: BoxDecoration(
                    color: shimmer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: Responsive.height(context, 6)),
                Container(
                  height: Responsive.height(context, 10),
                  width: Responsive.width(context, 120),
                  decoration: BoxDecoration(
                    color: shimmer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: Responsive.height(context, 16),
            width: Responsive.width(context, 50),
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final String price;
  final String? badge;
  final bool selected;
  final bool large;
  final Color appColor;
  final VoidCallback onTap;

  const _PlanTile({
    required this.label,
    required this.subtitle,
    required this.price,
    required this.badge,
    required this.selected,
    required this.large,
    required this.appColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = onTheme(appColor);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 18),
          vertical: Responsive.height(context, large ? 18 : 14),
        ),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    appColor.withAlpha(160),
                    lightenColor(appColor, 0.08).withAlpha(140),
                  ],
                )
              : null,
          color: selected ? null : Colors.black.withAlpha(30),
          borderRadius: BorderRadius.circular(Responsive.scale(context, 14)),
          border: Border.all(
            color: selected
                ? accent.withAlpha(220)
                : Colors.black.withAlpha(40),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withAlpha(80),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: accent.withAlpha(30),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, large ? 17 : 15),
                          color: selected ? accent : onTheme(appColor),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (badge != null) ...[
                        SizedBox(width: Responsive.width(context, 8)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 7),
                            vertical: Responsive.height(context, 2),
                          ),
                          decoration: BoxDecoration(
                            color: appColor.withAlpha(180),
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 20),
                            ),
                          ),
                          child: Text(
                            badge!,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 9),
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: Responsive.height(context, 2)),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 11),
                      color: onTheme(appColor),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, large ? 17 : 15),
                    color: selected ? accent : onTheme(appColor),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(top: Responsive.height(context, 4)),
                  width: Responsive.scale(context, 20),
                  height: Responsive.scale(context, 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? appColor : Colors.transparent,
                    border: Border.all(
                      color: selected ? accent : Colors.black.withAlpha(60),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check,
                          color: accent,
                          size: Responsive.scale(context, 12),
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Smooth looping particle painter with no snap reset
class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  static final _rng = math.Random(42);
  static final List<({double x, double yOffset, double speed, double size})>
  _particles = List.generate(
    20,
    (_) => (
      x: _rng.nextDouble(),
      yOffset: _rng.nextDouble(),
      speed: _rng.nextDouble() * 0.3 + 0.15,
      size: _rng.nextDouble() * 3 + 1.5,
    ),
  );

  const _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      // Each particle moves upward independently based on its speed
      // Using modulo so they loop seamlessly without snapping
      final phase = (p.yOffset + progress * p.speed) % 1.0;
      final py = (1.0 - phase) * size.height;
      final px = p.x * size.width;
      // Fade in from bottom, fade out toward top
      final alpha = (math.sin(phase * math.pi) * 70).toInt().clamp(0, 70);
      canvas.drawCircle(
        Offset(px, py),
        p.size,
        Paint()..color = color.withAlpha(alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
