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

Future<void> showPremiumSheet(BuildContext context, WidgetRef ref) async {
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

  List<ProductDetails> _products = [];
  bool _loading = true;
  bool _purchasing = false;
  String _selectedId = 'level_up_premium:yearly';
  Color? _originalColor;

  late final AnimationController _shimmerController;
  late final AnimationController _pulseController;
  late final AnimationController _particleController;

  @override
  void initState() {
    super.initState();
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
    final yearlyId = products
        .where((p) => p.id.contains('yearly'))
        .firstOrNull
        ?.id;
    setState(() {
      _products = products;
      _loading = false;
      if (yearlyId != null) _selectedId = yearlyId;
    });
  }

  ProductDetails? get _selectedProduct {
    for (final p in _products) {
      if (p.id == _selectedId) return p;
    }
    return null;
  }

  Future<void> _subscribe() async {
    final product = _selectedProduct;
    if (product == null || _purchasing) return;
    setState(() => _purchasing = true);
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
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, _) {
        final pos = _shimmerController.value;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.5 + pos * 3.5, 0),
            end: Alignment(-0.5 + pos * 3.5, 0),
            colors: [
              lightenColor(appColor, 0.3),
              lightenColor(appColor, 0.45),
              Colors.white,
              lightenColor(appColor, 0.45),
              lightenColor(appColor, 0.3),
            ],
            stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
          ).createShader(bounds),
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
      },
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
      if (rank == 2) return Colors.grey;
      if (rank == 3) return const Color(0xFFCD7F32);
      return Colors.white70;
    }

    Widget? rankMedal() {
      if (rank > 3) return null;
      return Icon(
        Icons.emoji_events,
        color: rankColor(),
        size: Responsive.scale(context, 16),
      );
    }

    final fraction = (xp / xpNeeded).clamp(0.0, 1.0);

    Widget nameWidget;
    if (isPro) {
      nameWidget = AnimatedBuilder(
        animation: _shimmerController,
        builder: (_, _) {
          final pos = _shimmerController.value;
          return ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(-1.5 + pos * 3.5, 0),
              end: Alignment(-0.5 + pos * 3.5, 0),
              colors: [
                lightenColor(appColor, 0.3),
                lightenColor(appColor, 0.55),
                Colors.white,
                lightenColor(appColor, 0.55),
                lightenColor(appColor, 0.3),
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ).createShader(bounds),
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
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 5),
                    vertical: Responsive.height(context, 1),
                  ),
                  decoration: BoxDecoration(
                    color: appColor.withAlpha(160),
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 4),
                    ),
                    border: Border.all(color: accent.withAlpha(160), width: 1),
                  ),
                  child: Text(
                    'PRO',
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 8),
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      nameWidget = Text(
        name,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 14),
          color: cardColors(appColor).onCard.withAlpha(180),
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
            ? lightenColor(appColor, 0.12).withAlpha(200)
            : cardColors(appColor).gradient.first.withAlpha(160),
        borderRadius: BorderRadius.circular(Responsive.scale(context, 14)),
        border: Border.all(
          color: isCurrentUser
              ? accent.withAlpha(120)
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
                child: Icon(
                  Icons.person,
                  color: accent.withAlpha(160),
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
                  color: cardColors(appColor).onCard.withAlpha(130),
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
    final isPreviewingAny = _originalColor != null;
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
                            width: isSelected ? 2 : 1,
                          ),
                        ),
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
                  child: Icon(
                    Icons.add,
                    color: Colors.white70,
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
                  Icon(
                    Icons.visibility_outlined,
                    color: cardColors(appColor).onCard,
                    size: Responsive.scale(context, 17),
                  ),
                  SizedBox(width: Responsive.width(context, 8)),
                  Text(
                    'Explore the app with this theme',
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

    // Tiered rows: features that exist in both but differ by limit
    // (feature, freeValue, proValue)
    final tieredRows = [
      ('Analytics history', '14 days', 'Full history'),
      ('Meal templates', 'Up to 5', 'Unlimited'),
      ('Recent foods', 'Up to 20', 'Unlimited'),
      ('Streak shields', 'None', 'Unlimited'),
      ('XP multiplier', 'Standard', 'Boosted'),
    ];

    // Pro-only extras not present in free at all
    const proExtras = ['Pro badge and shimmering name', 'Exclusive app themes'];

    Widget checkRow(String text, {required bool isPro}) => Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 5)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: Responsive.height(context, 2)),
            child: Icon(
              Icons.check,
              size: Responsive.scale(context, 11),
              color: isPro ? accent : onCard.withAlpha(100),
            ),
          ),
          SizedBox(width: Responsive.width(context, 5)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 11),
                color: isPro ? onCard : onCard.withAlpha(150),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );

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
              'FREE vs PRO',
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

        // Tiered rows card — same feature, two tiers side by side
        frostedGlassCard(
          context,
          color: appColor,
          baseRadius: 14,
          child: Column(
            children: [
              // Header row
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 14),
                  vertical: Responsive.height(context, 10),
                ),
                decoration: BoxDecoration(
                  color: cardColors(appColor).gradient.first.withAlpha(60),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(Responsive.scale(context, 14)),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    SizedBox(
                      width: Responsive.width(context, 72),
                      child: Center(
                        child: Text(
                          'Free',
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 12),
                            color: onCard.withAlpha(130),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: Responsive.width(context, 72),
                      child: Center(
                        child: _shimmerText(
                          'Pro',
                          Responsive.font(context, 12),
                          weight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (int i = 0; i < tieredRows.length; i++) ...[
                if (i > 0)
                  Divider(
                    color: cardColors(appColor).border.withAlpha(40),
                    height: 1,
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 14),
                    vertical: Responsive.height(context, 11),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tieredRows[i].$1,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 12),
                            color: onCard,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: Responsive.width(context, 72),
                        child: Center(
                          child: Text(
                            tieredRows[i].$2,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 11),
                              color: onCard.withAlpha(180),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: Responsive.width(context, 72),
                        child: Center(
                          child: Text(
                            tieredRows[i].$3,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 11),
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: Responsive.height(context, 10)),

        // Bottom row: Free summary + Pro extras side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Free included features — brief, not the star
            Expanded(
              child: frostedGlassCard(
                context,
                color: appColor,
                baseRadius: 14,
                padding: EdgeInsets.all(Responsive.scale(context, 14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Also included free',
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 11),
                        color: onCard.withAlpha(130),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 8)),
                    checkRow('Full food logging and macros', isPro: false),
                    checkRow('Barcode and voice search', isPro: false),
                    checkRow('Workout tracker', isPro: false),
                    checkRow('XP, levels and leaderboard', isPro: false),
                    checkRow('Explore tab check-ins', isPro: false),
                    checkRow('Badges and achievements', isPro: false),
                    checkRow('Daily rewards and streaks', isPro: false),
                    checkRow('Calorie calculator', isPro: false),
                    checkRow('Reminders', isPro: false),
                  ],
                ),
              ),
            ),
            SizedBox(width: Responsive.width(context, 10)),
            // Pro extras — visually dominant
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      appColor.withAlpha(120),
                      lightenColor(appColor, 0.1).withAlpha(100),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 14),
                  ),
                  border: Border.all(color: accent.withAlpha(140), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withAlpha(40),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                padding: EdgeInsets.all(Responsive.scale(context, 14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerText(
                      'Pro only',
                      Responsive.font(context, 11),
                      weight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                    SizedBox(height: Responsive.height(context, 8)),
                    for (final item in proExtras) checkRow(item, isPro: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBenefitRow(IconData icon, String text, int index) {
    return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: Responsive.scale(context, 32),
              height: Responsive.scale(context, 32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appColor.withAlpha(60),
                border: Border.all(
                  color: lightenColor(appColor, 0.4).withAlpha(100),
                  width: 1,
                ),
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  color: lightenColor(appColor, 0.45),
                  size: Responsive.scale(context, 15),
                ),
              ),
            ),
            SizedBox(width: Responsive.width(context, 12)),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 13),
                  color: lightenColor(appColor, 0.4),
                  height: 1.3,
                ),
              ),
            ),
          ],
        )
        .animate()
        .slideX(
          begin: -0.3,
          end: 0,
          delay: (index * 60).ms,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(delay: (index * 60).ms, duration: 350.ms);
  }

  Widget _trustSignal(IconData icon, String label, Color dim) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: dim, size: Responsive.scale(context, 12)),
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
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);
    final hPad = Responsive.width(context, 20);

    ref.listen(userDataProvider.select((s) => s.value?.isPremium ?? false), (
      _,
      isPremium,
    ) {
      if (isPremium && mounted) {
        badgesConfettiController.play();
        Navigator.of(context).pop();
      }
    });

    final monthly = _products
        .where((p) => p.id.contains('monthly'))
        .firstOrNull;
    final yearly = _products.where((p) => p.id.contains('yearly')).firstOrNull;

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
                                      'The health app, but make it legendary',
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

                          // Key benefits
                          _buildBenefitRow(
                            HugeIcons.strokeRoundedStar,
                            'XP multiplier. Rank up faster than everyone else.',
                            0,
                          ),
                          SizedBox(height: Responsive.height(context, 12)),
                          _buildBenefitRow(
                            HugeIcons.strokeRoundedFire,
                            'Streak shields so a missed day never kills your streak.',
                            1,
                          ),
                          SizedBox(height: Responsive.height(context, 12)),
                          _buildBenefitRow(
                            HugeIcons.strokeRoundedNote,
                            'Unlimited meal templates. Log any meal in one tap.',
                            2,
                          ),

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
                          if (kIsWeb) ...[
                            _PlanTile(
                              label: 'Yearly',
                              subtitle: 'Most popular, save over 50%',
                              price: '\$29.99 / yr',
                              badge: 'BEST VALUE',
                              selected: _selectedId.contains('yearly'),
                              large: true,
                              appColor: appColor,
                              onTap: () {
                                setState(
                                  () => _selectedId = 'level_up_premium:yearly',
                                );
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
                                        style: dialogButtonStyle(confirm: true),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            SizedBox(height: Responsive.height(context, 10)),
                            _PlanTile(
                              label: 'Monthly',
                              subtitle: 'Billed every month',
                              price: '\$4.99 / mo',
                              badge: null,
                              selected: _selectedId.contains('monthly'),
                              large: false,
                              appColor: appColor,
                              onTap: () {
                                setState(
                                  () =>
                                      _selectedId = 'level_up_premium:monthly',
                                );
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
                                        style: dialogButtonStyle(confirm: true),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ] else if (_loading) ...[
                            _SkeletonTile(appColor: appColor, tall: true),
                            SizedBox(height: Responsive.height(context, 10)),
                            _SkeletonTile(appColor: appColor, tall: false),
                          ] else ...[
                            _PlanTile(
                              label: 'Yearly',
                              subtitle: 'Most popular, save over 50%',
                              price: yearly?.price ?? '\$29.99',
                              badge: 'BEST VALUE',
                              selected: _selectedId.contains('yearly'),
                              large: true,
                              appColor: appColor,
                              onTap: () => setState(
                                () => _selectedId =
                                    yearly?.id ?? 'level_up_premium:yearly',
                              ),
                            ),
                            SizedBox(height: Responsive.height(context, 10)),
                            _PlanTile(
                              label: 'Monthly',
                              subtitle: 'Billed every month',
                              price: monthly?.price ?? '\$4.99',
                              badge: null,
                              selected: _selectedId.contains('monthly'),
                              large: false,
                              appColor: appColor,
                              onTap: () => setState(
                                () => _selectedId =
                                    monthly?.id ?? 'level_up_premium:monthly',
                              ),
                            ),
                          ],

                          SizedBox(height: Responsive.height(context, 28)),
                        ],
                      ),
                    ),
                  ),
                ),

                // CTA
                if (!kIsWeb)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      hPad,
                      0,
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
                            child: Text(
                              'Other fitness apps charge \$20+/mo. You pay ${_selectedId.contains('yearly') && yearly != null
                                  ? '${yearly.price}/yr'
                                  : monthly != null
                                  ? '${monthly.price}/mo'
                                  : ''}.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 11),
                                color: dim,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),

                        GestureDetector(
                          onTap: _purchasing ? null : _subscribe,
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (_, _) => Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                vertical: Responsive.height(context, 17),
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    appColor.withAlpha(_purchasing ? 100 : 200),
                                    lightenColor(
                                      appColor,
                                      0.15,
                                    ).withAlpha(_purchasing ? 100 : 220),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  Responsive.scale(context, 14),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withAlpha(
                                      _purchasing
                                          ? 0
                                          : (40 + 30 * _pulseController.value)
                                                .toInt(),
                                    ),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  ),
                                ],
                                border: Border.all(
                                  color: accent.withAlpha(100),
                                  width: 1,
                                ),
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
                                            fontSize: Responsive.font(
                                              context,
                                              16,
                                            ),
                                            color: accent,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        if (_selectedProduct != null) ...[
                                          SizedBox(
                                            height: Responsive.height(
                                              context,
                                              3,
                                            ),
                                          ),
                                          Text(
                                            _selectedId.contains('yearly')
                                                ? '${_selectedProduct!.price} / year (less than \$2.50/mo)'
                                                : '${_selectedProduct!.price} / month',
                                            style: GoogleFonts.manrope(
                                              fontSize: Responsive.font(
                                                context,
                                                11,
                                              ),
                                              color: accent.withAlpha(180),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 10)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _trustSignal(
                              Icons.cancel_outlined,
                              'Cancel anytime',
                              dim,
                            ),
                            SizedBox(width: Responsive.width(context, 16)),
                            _trustSignal(
                              Icons.lock_outline,
                              'Secure billing',
                              dim,
                            ),
                            SizedBox(width: Responsive.width(context, 16)),
                            _trustSignal(
                              Icons.restore,
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
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 18),
          vertical: Responsive.height(context, large ? 18 : 14),
        ),
        decoration: BoxDecoration(
          color: selected ? appColor.withAlpha(70) : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(Responsive.scale(context, 14)),
          border: Border.all(
            color: selected
                ? accent.withAlpha(200)
                : Colors.white.withAlpha(30),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withAlpha(40),
                    blurRadius: 12,
                    spreadRadius: 1,
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
                          color: selected ? accent : dim,
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
                      color: dim.withAlpha(180),
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
                    color: selected ? accent : dim,
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
                      color: selected ? accent : Colors.white.withAlpha(60),
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
