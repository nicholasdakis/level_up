import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import '/services/user_data_manager.dart'
    show authenticatedGet, authenticatedPost;

// Friendship state between the viewer and the profile owner
enum FriendStatus { none, pendingSent, pendingReceived, accepted }

// Block state between the viewer and the profile owner
enum BlockStatus { none, blockedByYou, blockedYou }

// Maps the backend friendship_status string to the local enum
FriendStatus _parseFriendStatus(String? raw) {
  switch (raw) {
    case 'pending_sent':
      return FriendStatus.pendingSent;
    case 'pending_received':
      return FriendStatus.pendingReceived;
    case 'accepted':
      return FriendStatus.accepted;
    default:
      return FriendStatus.none;
  }
}

// Maps the backend block_status string to the local enum
BlockStatus _parseBlockStatus(String? raw) {
  switch (raw) {
    case 'blocked_by_you':
      return BlockStatus.blockedByYou;
    case 'blocked_you':
      return BlockStatus.blockedYou;
    default:
      return BlockStatus.none;
  }
}

// Fetches public profile data and friendship status for a given uid from the backend
// Returns null on failure so callers can fall back gracefully
Future<(PublicProfile, FriendStatus, BlockStatus)?> fetchProfileCardData(
  String uid,
) async {
  try {
    final response = await authenticatedGet('user_profile_card?uid=$uid');
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    Uint8List? pfpBytes;
    if (data['pfp_base64'] != null) {
      pfpBytes = base64Decode(data['pfp_base64'] as String);
    }
    final profile = PublicProfile(
      uid: data['uid'] as String,
      username: (data['username'] as String?) ?? 'Unnamed',
      level: data['level'] as int,
      expPoints: data['exp_points'] as int,
      pfpBytes: pfpBytes,
      isPremium: data['is_premium'] as bool,
      joinedAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
      bestDailyStreak: data['best_daily_streak'] as int,
      bestFoodStreak: data['best_food_streak'] as int,
      bestWorkoutStreak: data['best_workout_streak'] as int,
    );
    final friendStatus = _parseFriendStatus(
      data['friendship_status'] as String?,
    );
    final blockStatus = _parseBlockStatus(data['block_status'] as String?);
    return (profile, friendStatus, blockStatus);
  } catch (e) {
    if (kDebugMode) debugPrint('fetchProfileCardData error: $e');
    return null;
  }
}

// Public profile data returned by the backend for any user
// Only contains fields safe to expose to other users (no email, goals, weight, etc)
class PublicProfile {
  final String uid;
  final String username;
  final int level;
  final int expPoints;
  final Uint8List? pfpBytes;
  final bool isPremium;
  final DateTime? joinedAt;
  final int bestDailyStreak;
  final int bestFoodStreak;
  final int bestWorkoutStreak;

  const PublicProfile({
    required this.uid,
    required this.username,
    required this.level,
    required this.expPoints,
    this.pfpBytes,
    this.isPremium = false,
    this.joinedAt,
    this.bestDailyStreak = 0,
    this.bestFoodStreak = 0,
    this.bestWorkoutStreak = 0,
  });
}

// XP needed to reach the next level, matching the formula used on the leaderboard
int _expNeeded(int level) {
  int exp = (100 * pow(1.25, level - 0.5) * 1.05 + (level * 10)).round();
  return (exp / 10).round() * 10;
}

// Formats a join date as "Joined Jan 2025"
String _joinedLabel(DateTime? date) {
  if (date == null) return '';
  const months = [
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
  return 'Joined ${months[date.month - 1]} ${date.year}';
}

// Preset nudge messages the sender can pick from
const _nudgePresets = [
  'Come claim your daily reward!',
  "Don't lose your streak!",
  'Time to log your food!',
  'Let\'s get a workout in!',
];

// Dialog for sending a nudge to a friend. Shows preset messages and a custom input
// Capped at 100 characters to keep notifications readable
Future<void> _showNudgeDialog(
  BuildContext context,
  Color appColor,
  String toUsername,
  String targetUid,
) async {
  final controller = TextEditingController();
  String? selected = _nudgePresets.first;
  bool useCustom = false;

  await showFrostedDialog(
    context: context,
    appColor: appColor,
    child: StatefulBuilder(
      builder: (ctx, setState) {
        final primary = lightenColor(appColor, 0.45);
        final dim = lightenColor(appColor, 0.30);
        final c = cardColors(appColor);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nudge $toUsername',
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(ctx, 18),
                fontWeight: FontWeight.w800,
                color: primary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Responsive.height(ctx, 6)),
            Text(
              'Pick a message to send as a push notification.',
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(ctx, 13),
                color: dim,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Responsive.height(ctx, 20)),

            // Preset message options
            for (final preset in _nudgePresets) ...[
              GestureDetector(
                onTap: () => setState(() {
                  selected = preset;
                  useCustom = false;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(ctx, 14),
                    vertical: Responsive.height(ctx, 11),
                  ),
                  decoration: BoxDecoration(
                    gradient: (!useCustom && selected == preset)
                        ? LinearGradient(
                            colors: c.gradient,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: (!useCustom && selected == preset)
                        ? null
                        : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(ctx, 10),
                    ),
                    border: Border.all(
                      color: (!useCustom && selected == preset)
                          ? c.border
                          : Colors.white.withAlpha(25),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    preset,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(ctx, 13),
                      fontWeight: (!useCustom && selected == preset)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: Responsive.height(ctx, 6)),
            ],

            // Option to write a custom message instead
            GestureDetector(
              onTap: () => setState(() {
                useCustom = true;
                selected = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(ctx, 14),
                  vertical: Responsive.height(ctx, 11),
                ),
                decoration: BoxDecoration(
                  gradient: useCustom
                      ? LinearGradient(
                          colors: c.gradient,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: useCustom ? null : Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(ctx, 10),
                  ),
                  border: Border.all(
                    color: useCustom ? c.border : Colors.white.withAlpha(25),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedPencilEdit01,
                      color: Colors.white,
                      size: Responsive.scale(ctx, 14),
                    ),
                    SizedBox(width: Responsive.width(ctx, 8)),
                    Text(
                      'Write my own',
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(ctx, 13),
                        fontWeight: useCustom
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Custom message text field, shown only when "Write my own" is selected
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutQuart,
              child: useCustom
                  ? Padding(
                      padding: EdgeInsets.only(top: Responsive.height(ctx, 10)),
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        maxLength: 100,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: Responsive.font(ctx, 13),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Say something...',
                          hintStyle: GoogleFonts.manrope(
                            color: Colors.white38,
                            fontSize: Responsive.font(ctx, 13),
                          ),
                          counterStyle: GoogleFonts.manrope(
                            color: dim,
                            fontSize: Responsive.font(ctx, 11),
                          ),
                          suffixIcon: const SizedBox.shrink(),
                          suffixIconConstraints: const BoxConstraints(
                            maxWidth: 0,
                          ),
                          filled: true,
                          fillColor: Colors.white.withAlpha(10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(ctx, 10),
                            ),
                            borderSide: BorderSide(
                              color: Colors.white.withAlpha(25),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(ctx, 10),
                            ),
                            borderSide: BorderSide(
                              color: Colors.white.withAlpha(25),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(ctx, 10),
                            ),
                            borderSide: BorderSide(color: c.border, width: 1.5),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(ctx, 12),
                            vertical: Responsive.height(ctx, 10),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            SizedBox(height: Responsive.height(ctx, 20)),

            // Send button, disabled if the custom field is empty
            GestureDetector(
              onTap: () async {
                final message = useCustom
                    ? controller.text.trim()
                    : selected ?? '';
                if (message.isEmpty) return;
                final confirmed = await showFrostedAlertDialog<bool>(
                  context: ctx,
                  appColor: appColor,
                  title: 'Nudge $toUsername?',
                  content: Text(
                    '"$message"',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: Responsive.font(ctx, 13),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(ctx, rootNavigator: true).pop(false),
                      child: Text('Back', style: dialogButtonStyle()),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(ctx, rootNavigator: true).pop(true),
                      child: Text(
                        'Send',
                        style: dialogButtonStyle(confirm: true),
                      ),
                    ),
                  ],
                );
                if (confirmed != true) return;
                if (!ctx.mounted) return;
                Navigator.of(ctx, rootNavigator: true).pop();
                final nudgeRes = await authenticatedPost(
                  'friends/nudge',
                  body: {'target_uid': targetUid, 'message': message},
                );
                if (context.mounted) {
                  final String snackText;
                  if (nudgeRes.statusCode == 429) {
                    snackText =
                        'You\'ve nudged $toUsername too many times. Try again later.';
                  } else {
                    final body =
                        jsonDecode(nudgeRes.body) as Map<String, dynamic>;
                    if (body['reason'] == 'nudges_disabled') {
                      snackText =
                          '$toUsername has nudge notifications turned off.';
                    } else {
                      snackText = 'Nudge sent to $toUsername';
                    }
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        snackText,
                        style: GoogleFonts.manrope(color: Colors.white),
                      ),
                      duration: snackBarDuration,
                    ),
                  );
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.height(ctx, 14),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: c.gradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(ctx, 12),
                  ),
                  border: Border.all(color: c.border, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedSent,
                      color: Colors.white,
                      size: Responsive.scale(ctx, 18),
                    ),
                    SizedBox(width: Responsive.width(ctx, 8)),
                    Text(
                      'Send Nudge',
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(ctx, 14),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

// Opens a profile card dialog for any user by uid
// The dialog shows a skeleton immediately and populates once the fetch resolves
Future<void> showProfileCard(
  BuildContext context, {
  required String uid,
  required Color appColor,
  required bool isOwnProfile,
  VoidCallback? onAddFriend,
  VoidCallback? onCancelRequest,
  VoidCallback? onAccept,
  VoidCallback? onDecline,
  VoidCallback? onUnfriend,
  VoidCallback? onBlock,
  VoidCallback? onUnblock,
}) {
  return showFrostedDialog(
    context: context,
    appColor: appColor,
    child: _ProfileCardLoader(
      uid: uid,
      appColor: appColor,
      isOwnProfile: isOwnProfile,
      onAddFriend: onAddFriend,
      onCancelRequest: onCancelRequest,
      onAccept: onAccept,
      onDecline: onDecline,
      onUnfriend: onUnfriend,
      onBlock: onBlock,
      onUnblock: onUnblock,
    ),
  );
}

// Kicks off the fetch and holds the result in state
// Renders a skeleton until the data arrives
class _ProfileCardLoader extends StatefulWidget {
  final String uid;
  final Color appColor;
  final bool isOwnProfile;
  final VoidCallback? onAddFriend;
  final VoidCallback? onCancelRequest;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onUnfriend;
  final VoidCallback? onBlock;
  final VoidCallback? onUnblock;

  const _ProfileCardLoader({
    required this.uid,
    required this.appColor,
    required this.isOwnProfile,
    this.onAddFriend,
    this.onCancelRequest,
    this.onAccept,
    this.onDecline,
    this.onUnfriend,
    this.onBlock,
    this.onUnblock,
  });

  @override
  State<_ProfileCardLoader> createState() => _ProfileCardLoaderState();
}

class _ProfileCardLoaderState extends State<_ProfileCardLoader> {
  PublicProfile? _profile;
  FriendStatus _friendStatus = FriendStatus.none;
  BlockStatus _blockStatus = BlockStatus.none;

  @override
  void initState() {
    super.initState();
    fetchProfileCardData(widget.uid).then((result) {
      if (mounted && result != null) {
        setState(() {
          _profile = result.$1;
          _friendStatus = result.$2;
          _blockStatus = result.$3;
        });
      }
    });
  }

  Future<void> _block() async {
    final username = _profile?.username ?? 'this user';
    final confirmed = await showHoldToConfirmDialog(
      context: context,
      appColor: widget.appColor,
      title: 'Block $username?',
      subtitle:
          'They won\'t be able to find your profile or send you friend requests.',
      icon: HugeIcons.strokeRoundedUserRemove01,
    );
    if (confirmed != true) return;
    setState(() {
      _blockStatus = BlockStatus.blockedByYou;
      _friendStatus = FriendStatus.none;
    });
    await authenticatedPost('block', body: {'target_uid': widget.uid});
    widget.onBlock?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$username has been blocked',
          style: GoogleFonts.manrope(color: Colors.white),
        ),
        duration: snackBarDuration,
      ),
    );
  }

  Future<void> _unblock() async {
    final username = _profile?.username ?? 'this user';
    final confirmed = await showFrostedAlertDialog<bool>(
      context: context,
      appColor: widget.appColor,
      title: 'Unblock $username?',
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: Text('Cancel', style: dialogButtonStyle()),
        ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: Text('Unblock', style: dialogButtonStyle(confirm: true)),
        ),
      ],
    );
    if (confirmed != true) return;
    setState(() => _blockStatus = BlockStatus.none);
    await authenticatedPost('unblock', body: {'target_uid': widget.uid});
    widget.onUnblock?.call();
  }

  Future<void> _sendFriendAction(
    String action,
    FriendStatus optimisticStatus,
  ) async {
    setState(() => _friendStatus = optimisticStatus);
    await authenticatedPost(
      'friends/request',
      body: {'target_uid': widget.uid, 'action': action},
    );
    if (!mounted) return;
    final username = _profile?.username ?? 'User';
    final message = switch (action) {
      'send' => 'Friend request sent to $username',
      'accept' => "You and $username are now friends",
      'decline' => 'Friend request declined',
      'cancel' => 'Friend request cancelled',
      _ => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.manrope(color: Colors.white),
          ),
          duration: snackBarDuration,
        ),
      );
    }
    switch (action) {
      case 'accept':
        widget.onAccept?.call();
      case 'decline':
        widget.onDecline?.call();
      case 'cancel':
        widget.onCancelRequest?.call();
      case 'send':
        widget.onAddFriend?.call();
    }
  }

  Future<void> _unfriend() async {
    final username = _profile?.username ?? 'this user';
    final confirmed = await showHoldToConfirmDialog(
      context: context,
      appColor: widget.appColor,
      title: 'Unfriend $username?',
      subtitle: 'You will need to send a new friend request to reconnect.',
      icon: HugeIcons.strokeRoundedUserRemove01,
    );
    if (confirmed != true) return;
    setState(() => _friendStatus = FriendStatus.none);
    await authenticatedPost(
      'friends/unfriend',
      body: {'target_uid': widget.uid},
    );
    widget.onUnfriend?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Removed $username from friends',
          style: GoogleFonts.manrope(color: Colors.white),
        ),
        duration: snackBarDuration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileCardContent(
      profile: _profile,
      appColor: widget.appColor,
      isOwnProfile: widget.isOwnProfile,
      friendStatus: _friendStatus,
      blockStatus: _blockStatus,
      onAddFriend: () => _sendFriendAction('send', FriendStatus.pendingSent),
      onCancelRequest: () => _sendFriendAction('cancel', FriendStatus.none),
      onAccept: () => _sendFriendAction('accept', FriendStatus.accepted),
      onDecline: () => _sendFriendAction('decline', FriendStatus.none),
      onNudge: _friendStatus == FriendStatus.accepted && _profile != null
          ? () => _showNudgeDialog(
              context,
              widget.appColor,
              _profile!.username,
              widget.uid,
            )
          : null,
      onUnfriend: _unfriend,
      onBlock: _block,
      onUnblock: _unblock,
    );
  }
}

// Skeleton shown while profile data is loading
class _ProfileCardSkeleton extends StatelessWidget {
  final Color appColor;
  final Color primary;
  final Color dim;

  const _ProfileCardSkeleton({
    required this.appColor,
    required this.primary,
    required this.dim,
  });

  @override
  Widget build(BuildContext context) {
    final shimmer = Colors.white.withAlpha(30);
    final shimmerDark = Colors.white.withAlpha(15);

    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: shimmer,
        borderRadius: BorderRadius.circular(Responsive.scale(context, 6)),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: Responsive.scale(context, 60),
              height: Responsive.scale(context, 60),
              decoration: BoxDecoration(shape: BoxShape.circle, color: shimmer),
            ),
            SizedBox(width: Responsive.width(context, 14)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(
                  Responsive.width(context, 120),
                  Responsive.height(context, 16),
                ),
                SizedBox(height: Responsive.height(context, 6)),
                bar(
                  Responsive.width(context, 60),
                  Responsive.height(context, 12),
                ),
                SizedBox(height: Responsive.height(context, 6)),
                bar(
                  Responsive.width(context, 80),
                  Responsive.height(context, 10),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: Responsive.height(context, 20)),
        bar(double.infinity, Responsive.height(context, 7)),
        SizedBox(height: Responsive.height(context, 20)),
        Row(
          children: [
            for (int i = 0; i < 3; i++) ...[
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: Responsive.scale(context, 18),
                      height: Responsive.scale(context, 18),
                      decoration: BoxDecoration(
                        color: shimmerDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 6)),
                    bar(
                      Responsive.width(context, 30),
                      Responsive.height(context, 20),
                    ),
                    SizedBox(height: Responsive.height(context, 4)),
                    bar(
                      Responsive.width(context, 40),
                      Responsive.height(context, 10),
                    ),
                  ],
                ),
              ),
              if (i < 2)
                Container(
                  width: 1,
                  height: Responsive.height(context, 48),
                  color: Colors.white.withAlpha(20),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

// Renders the profile card content once data is available
// Shows a skeleton when profile is null
class _ProfileCardContent extends StatelessWidget {
  final PublicProfile? profile;
  final Color appColor;
  final bool isOwnProfile;
  final FriendStatus friendStatus;
  final BlockStatus blockStatus;
  final VoidCallback? onAddFriend;
  final VoidCallback? onCancelRequest;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onNudge;
  final VoidCallback? onUnfriend;
  final VoidCallback? onBlock;
  final VoidCallback? onUnblock;

  const _ProfileCardContent({
    required this.profile,
    required this.appColor,
    required this.isOwnProfile,
    required this.friendStatus,
    this.blockStatus = BlockStatus.none,
    this.onAddFriend,
    this.onCancelRequest,
    this.onAccept,
    this.onDecline,
    this.onNudge,
    this.onUnfriend,
    this.onBlock,
    this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    final primary = lightenColor(appColor, 0.45);
    final secondary = lightenColor(appColor, 0.35);
    final dim = lightenColor(appColor, 0.30);

    if (profile == null) {
      return _ProfileCardSkeleton(
        appColor: appColor,
        primary: primary,
        dim: dim,
      );
    }

    final expNeeded = _expNeeded(profile!.level);
    final progress = (profile!.expPoints / expNeeded).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Avatar, username, level, joined date
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(context),
            SizedBox(width: Responsive.width(context, 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile!.username,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 18),
                            fontWeight: FontWeight.w800,
                            color: primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile!.isPremium) ...[
                        SizedBox(width: Responsive.width(context, 6)),
                        Icon(
                          Icons.verified_rounded,
                          size: Responsive.scale(context, 16),
                          color: lightenColor(appColor, 0.4),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: Responsive.height(context, 2)),
                  Text(
                    'Level ${profile!.level}',
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 13),
                      fontWeight: FontWeight.w600,
                      color: secondary,
                    ),
                  ),
                  if (profile!.joinedAt != null) ...[
                    SizedBox(height: Responsive.height(context, 2)),
                    Text(
                      _joinedLabel(profile!.joinedAt),
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 12),
                        color: dim,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isOwnProfile &&
                blockStatus != BlockStatus.blockedYou &&
                (blockStatus == BlockStatus.blockedByYou ||
                    friendStatus == FriendStatus.accepted ||
                    friendStatus == FriendStatus.none ||
                    friendStatus == FriendStatus.pendingSent ||
                    friendStatus == FriendStatus.pendingReceived))
              GestureDetector(
                onTap: () => showFrostedAlertDialog(
                  context: context,
                  appColor: appColor,
                  title: blockStatus == BlockStatus.blockedByYou
                      ? 'Blocked User'
                      : 'Manage',
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      child: Text('Close', style: dialogButtonStyle()),
                    ),
                    if (blockStatus == BlockStatus.blockedByYou)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop();
                          onUnblock?.call();
                        },
                        child: Text(
                          'Unblock',
                          style: dialogButtonStyle(confirm: true),
                        ),
                      )
                    else ...[
                      if (friendStatus == FriendStatus.accepted)
                        TextButton(
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).pop();
                            onUnfriend?.call();
                          },
                          child: Text(
                            'Unfriend',
                            style: dialogButtonStyle(confirm: true),
                          ),
                        ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop();
                          onBlock?.call();
                        },
                        child: Text(
                          'Block',
                          style: dialogButtonStyle(confirm: true),
                        ),
                      ),
                    ],
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.only(left: Responsive.width(context, 8)),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    color: dim,
                    size: Responsive.scale(context, 20),
                  ),
                ),
              ),
          ],
        ),

        SizedBox(height: Responsive.height(context, 20)),

        // XP progress toward the next level
        _xpBar(context, progress, primary, dim, expNeeded),

        SizedBox(height: Responsive.height(context, 20)),

        // Best streak counts across daily, food, and workout
        _streakRow(context, primary, dim),

        // Action buttons are hidden on the viewer's own profile
        if (!isOwnProfile) ...[
          SizedBox(height: Responsive.height(context, 24)),
          _actionButtons(context),
        ],
      ],
    );
  }

  Widget _avatar(BuildContext context) {
    final size = Responsive.scale(context, 60);
    if (profile!.pfpBytes != null) {
      return ClipOval(
        child: Image.memory(
          profile!.pfpBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cardColors(appColor).iconBox,
        border: Border.all(color: cardColors(appColor).border, width: 1.5),
      ),
      child: Icon(
        Icons.person_rounded,
        color: lightenColor(appColor, 0.40),
        size: Responsive.scale(context, 30),
      ),
    );
  }

  Widget _xpBar(
    BuildContext context,
    double progress,
    Color primary,
    Color dim,
    int expNeeded,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'XP Progress',
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 12),
                fontWeight: FontWeight.w600,
                color: dim,
              ),
            ),
            Text(
              '${profile!.expPoints} / $expNeeded',
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 12),
                color: dim,
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.height(context, 6)),
        ClipRRect(
          borderRadius: BorderRadius.circular(Responsive.scale(context, 6)),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: Responsive.height(context, 7),
            backgroundColor: Colors.white.withAlpha(15),
            valueColor: AlwaysStoppedAnimation(primary),
          ),
        ),
      ],
    );
  }

  Widget _streakRow(BuildContext context, Color primary, Color dim) {
    return Row(
      children: [
        _streakStat(
          context,
          HugeIcons.strokeRoundedFire,
          'Daily',
          profile!.bestDailyStreak,
          primary,
          dim,
        ),
        _divider(context),
        _streakStat(
          context,
          HugeIcons.strokeRoundedRestaurant03,
          'Food',
          profile!.bestFoodStreak,
          primary,
          dim,
        ),
        _divider(context),
        _streakStat(
          context,
          HugeIcons.strokeRoundedDumbbell01,
          'Workout',
          profile!.bestWorkoutStreak,
          primary,
          dim,
        ),
      ],
    );
  }

  Widget _streakStat(
    BuildContext context,
    IconData icon,
    String label,
    int value,
    Color primary,
    Color dim,
  ) {
    return Expanded(
      child: Column(
        children: [
          HugeIcon(icon: icon, color: dim, size: Responsive.scale(context, 18)),
          SizedBox(height: Responsive.height(context, 4)),
          Text(
            '$value',
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 20),
              fontWeight: FontWeight.w800,
              color: primary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 11),
              color: dim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: 1,
      height: Responsive.height(context, 48),
      color: Colors.white.withAlpha(20),
    );
  }

  // Renders the correct action button(s) based on the viewer's friendship status with this user
  Widget _actionButtons(BuildContext context) {
    if (blockStatus == BlockStatus.blockedByYou) {
      return _fullButton(
        context,
        label: 'Unblock',
        icon: HugeIcons.strokeRoundedUserAdd01,
        onTap: onUnblock ?? () {},
        muted: true,
      );
    }
    if (blockStatus == BlockStatus.blockedYou) {
      return _fullButton(
        context,
        label: 'Blocked',
        icon: HugeIcons.strokeRoundedUserRemove01,
        onTap: () {},
        muted: true,
      );
    }
    switch (friendStatus) {
      case FriendStatus.none:
        return _fullButton(
          context,
          label: 'Add Friend',
          icon: HugeIcons.strokeRoundedUserAdd01,
          onTap: onAddFriend ?? () {},
        );

      case FriendStatus.pendingSent:
        // Tapping the greyed button cancels the pending request
        return _fullButton(
          context,
          label: 'Request Sent',
          icon: HugeIcons.strokeRoundedClock01,
          onTap: onCancelRequest ?? () {},
          muted: true,
        );

      case FriendStatus.pendingReceived:
        return Row(
          children: [
            Expanded(
              child: _fullButton(
                context,
                label: 'Accept',
                icon: HugeIcons.strokeRoundedUserCheck01,
                onTap: onAccept ?? () {},
              ),
            ),
            SizedBox(width: Responsive.width(context, 10)),
            Expanded(
              child: _fullButton(
                context,
                label: 'Decline',
                icon: HugeIcons.strokeRoundedUserRemove01,
                onTap: onDecline ?? () {},
                muted: true,
              ),
            ),
          ],
        );

      case FriendStatus.accepted:
        return _fullButton(
          context,
          label: 'Nudge',
          icon: HugeIcons.strokeRoundedSent,
          onTap: onNudge ?? () {},
        );
    }
  }

  // Full-width button used for primary actions (Add Friend, Nudge, Accept, Decline)
  Widget _fullButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool muted = false,
  }) {
    final c = cardColors(appColor);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 14)),
        decoration: BoxDecoration(
          gradient: muted
              ? null
              : LinearGradient(
                  colors: c.gradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: muted ? Colors.white.withAlpha(12) : null,
          borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
          border: Border.all(
            color: muted ? Colors.white.withAlpha(30) : c.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: icon,
              color: Colors.white,
              size: Responsive.scale(context, 16),
            ),
            SizedBox(width: Responsive.width(context, 8)),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 14),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
