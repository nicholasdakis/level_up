import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_fonts/google_fonts.dart';
import '../globals.dart';
import '../providers/user_data_provider.dart';
import '../providers/friends_provider.dart';
import '../services/user_data_manager.dart'
    show authenticatedPost, defaultAppColor;
import '../utility/responsive.dart';
import 'social/friends_card.dart'
    show showAddFriendDialog, showUsernameDialog, friendsPendingBadge;
import 'widgets/profile_card.dart' show showProfileCard;

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  bool _incomingExpanded = false;
  bool _outgoingExpanded = false;
  int _friendsPage = 0;
  static const int _friendsPerPage = 11;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/social',
      screenClass: 'SocialScreen',
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _incomingExpanded = false;
      _outgoingExpanded = false;
      _friendsPage = 0;
    });
    await ref.read(friendsProvider.notifier).refresh();
  }

  Future<void> _showFriendSearch(BuildContext context, Color appColor) async {
    List<FriendEntry> results = [];
    bool searched = false;

    await showUsernameDialog(
      context: context,
      appColor: appColor,
      title: 'Search Friends',
      subtitle: 'Search within your friends list',
      confirmLabel: 'Search',
      onConfirm: (query, setState, ctx) async {
        setState(() {
          searched = false;
        });
        final hits = await ref
            .read(friendsProvider.notifier)
            .searchFriends(query);
        if (!ctx.mounted) return;
        setState(() {
          results = hits;
          searched = true;
        });
      },
      extra: (setState, ctx) {
        if (!searched) return const SizedBox.shrink();
        final primary = lightenColor(appColor, 0.45);
        final dim = lightenColor(appColor, 0.30);
        final c = cardColors(appColor);
        return Padding(
          padding: EdgeInsets.only(top: Responsive.height(ctx, 16)),
          child: results.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(bottom: Responsive.height(ctx, 8)),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'No friends found',
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(ctx, 13),
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final friend in results)
                      GestureDetector(
                        onTap: () {
                          Navigator.of(ctx, rootNavigator: true).pop();
                          showProfileCard(
                            context,
                            uid: friend.uid,
                            appColor: appColor,
                            isOwnProfile: false,
                            onUnfriend: () => ref
                                .read(friendsProvider.notifier)
                                .removeFriend(friend.uid),
                            onBlock: () => ref
                                .read(friendsProvider.notifier)
                                .removeFriend(friend.uid),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: Responsive.height(ctx, 10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: Responsive.scale(ctx, 38),
                                height: Responsive.scale(ctx, 38),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c.iconBox,
                                  border: Border.all(
                                    color: c.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: friend.pfpBytes != null
                                      ? Image.memory(
                                          friend.pfpBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : Icon(
                                          Icons.person_rounded,
                                          color: lightenColor(appColor, 0.40),
                                          size: Responsive.scale(ctx, 20),
                                        ),
                                ),
                              ),
                              SizedBox(width: Responsive.width(ctx, 10)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend.username,
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(ctx, 13),
                                        fontWeight: FontWeight.w700,
                                        color: primary,
                                      ),
                                    ),
                                    Text(
                                      'Level ${friend.level}',
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(ctx, 11),
                                        color: dim,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.30);
    final c = cardColors(appColor);
    final friendsAsync = ref.watch(friendsProvider);

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: primary,
          backgroundColor: Colors.transparent,
          child: ScrollConfiguration(
            behavior: NoGlowScrollBehavior(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.centeredHorizontalPadding(context, 20),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height:
                              MediaQuery.paddingOf(context).top +
                              Responsive.height(context, 24),
                        ),

                        // Header
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  sectionHeader(
                                    'FRIENDS',
                                    context,
                                    appColor: appColor,
                                  ),
                                ],
                              ),
                            ),
                            _headerButton(
                              context,
                              'Search',
                              c,
                              onTap: () => _showFriendSearch(context, appColor),
                            ),
                          ],
                        ),
                        SizedBox(height: Responsive.height(context, 12)),

                        if (friendsAsync.hasError)
                          Center(
                            child: Text(
                              'Failed to load',
                              style: GoogleFonts.manrope(color: dim),
                            ),
                          )
                        else
                          Skeletonizer(
                            enabled: friendsAsync.isLoading,
                            effect: ShimmerEffect(
                              baseColor: c.iconBox,
                              highlightColor: c.border,
                              duration: const Duration(milliseconds: 1200),
                            ),
                            child: Builder(
                              builder: (context) {
                                final data =
                                    friendsAsync.value ?? const FriendsState();
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      height: Responsive.height(context, 10),
                                    ),
                                    _friendsGrid(context, primary, dim, data),
                                    SizedBox(
                                      height: Responsive.height(context, 20),
                                    ),
                                    sectionHeader(
                                      'FRIEND REQUESTS',
                                      context,
                                      appColor: appColor,
                                    ),
                                    SizedBox(
                                      height: Responsive.height(context, 10),
                                    ),
                                    frostedGlassCard(
                                      context,
                                      color: appColor,
                                      baseRadius: 16,
                                      padding: EdgeInsets.all(
                                        Responsive.scale(context, 16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _collapsibleHeader(
                                            context,
                                            'Incoming',
                                            data.incomingCount,
                                            _incomingExpanded,
                                            primary,
                                            dim,
                                            onTap: () async {
                                              if (!_incomingExpanded) {
                                                await ref
                                                    .read(
                                                      friendsProvider.notifier,
                                                    )
                                                    .expandIncoming();
                                              }
                                              setState(
                                                () => _incomingExpanded =
                                                    !_incomingExpanded,
                                              );
                                            },
                                          ),
                                          if (_incomingExpanded) ...[
                                            SizedBox(
                                              height: Responsive.height(
                                                context,
                                                8,
                                              ),
                                            ),
                                            if (data.incoming.isEmpty)
                                              _sectionEmptyState(
                                                context,
                                                dim,
                                                'No pending requests',
                                              ),
                                            for (final entry in data.incoming)
                                              _entryRow(
                                                context,
                                                entry,
                                                primary,
                                                dim,
                                                c,
                                                trailing: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    _actionButton(
                                                      context,
                                                      'Accept',
                                                      c,
                                                      onTap: () async {
                                                        await authenticatedPost(
                                                          'friends/request',
                                                          body: {
                                                            'target_uid':
                                                                entry.uid,
                                                            'action': 'accept',
                                                          },
                                                        );
                                                        _refresh();
                                                        if (!mounted) return;
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'You and ${entry.username} are now friends',
                                                              style:
                                                                  GoogleFonts.manrope(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                            ),
                                                            duration:
                                                                snackBarDuration,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    SizedBox(
                                                      width: Responsive.width(
                                                        context,
                                                        6,
                                                      ),
                                                    ),
                                                    _actionButton(
                                                      context,
                                                      'Decline',
                                                      c,
                                                      muted: true,
                                                      onTap: () async {
                                                        final confirmed = await showFrostedAlertDialog<bool>(
                                                          context: context,
                                                          appColor: appColor,
                                                          title:
                                                              'Decline request?',
                                                          content: Text(
                                                            'Are you sure you want to decline ${entry.username}\'s friend request?',
                                                            style: GoogleFonts.manrope(
                                                              color:
                                                                  Colors.white,
                                                              fontSize:
                                                                  Responsive.font(
                                                                    context,
                                                                    13,
                                                                  ),
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    context,
                                                                    rootNavigator:
                                                                        true,
                                                                  ).pop(false),
                                                              child: Text(
                                                                'Cancel',
                                                                style:
                                                                    dialogButtonStyle(),
                                                              ),
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    context,
                                                                    rootNavigator:
                                                                        true,
                                                                  ).pop(true),
                                                              child: Text(
                                                                'Decline',
                                                                style:
                                                                    dialogButtonStyle(
                                                                      confirm:
                                                                          true,
                                                                    ),
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                        if (confirmed != true) {
                                                          return;
                                                        }
                                                        await authenticatedPost(
                                                          'friends/request',
                                                          body: {
                                                            'target_uid':
                                                                entry.uid,
                                                            'action': 'decline',
                                                          },
                                                        );
                                                        _refresh();
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (data.incomingHasMore)
                                              _loadMoreButton(
                                                context,
                                                primary,
                                                () => ref
                                                    .read(
                                                      friendsProvider.notifier,
                                                    )
                                                    .expandIncoming(),
                                              ),
                                          ],
                                          _divider(context),
                                          _collapsibleHeader(
                                            context,
                                            'Sent',
                                            data.outgoingCount,
                                            _outgoingExpanded,
                                            primary,
                                            dim,
                                            onTap: () async {
                                              if (!_outgoingExpanded) {
                                                await ref
                                                    .read(
                                                      friendsProvider.notifier,
                                                    )
                                                    .expandOutgoing();
                                              }
                                              setState(
                                                () => _outgoingExpanded =
                                                    !_outgoingExpanded,
                                              );
                                            },
                                          ),
                                          if (_outgoingExpanded) ...[
                                            SizedBox(
                                              height: Responsive.height(
                                                context,
                                                8,
                                              ),
                                            ),
                                            if (data.outgoing.isEmpty)
                                              _sectionEmptyState(
                                                context,
                                                dim,
                                                'No sent requests',
                                              ),
                                            for (final entry in data.outgoing)
                                              _entryRow(
                                                context,
                                                entry,
                                                primary,
                                                dim,
                                                c,
                                                trailing: _actionButton(
                                                  context,
                                                  'Cancel',
                                                  c,
                                                  muted: true,
                                                  onTap: () async {
                                                    await authenticatedPost(
                                                      'friends/request',
                                                      body: {
                                                        'target_uid': entry.uid,
                                                        'action': 'cancel',
                                                      },
                                                    );
                                                    _refresh();
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Friend request to ${entry.username} cancelled',
                                                          style:
                                                              GoogleFonts.manrope(
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        ),
                                                        duration:
                                                            snackBarDuration,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            if (data.outgoingHasMore)
                                              _loadMoreButton(
                                                context,
                                                primary,
                                                () => ref
                                                    .read(
                                                      friendsProvider.notifier,
                                                    )
                                                    .expandOutgoing(),
                                              ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                        SizedBox(height: Responsive.height(context, 120)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerButton(
    BuildContext context,
    String label,
    ({
      List<Color> gradient,
      Color border,
      Color iconBox,
      Color iconBorder,
      Color splashColor,
      Color highlightColor,
      Color onCard,
    })
    c, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minWidth: Responsive.width(context, 70)),
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 14),
          vertical: Responsive.height(context, 8),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: c.gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
          border: Border.all(color: c.border, width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 13),
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _friendsGrid(
    BuildContext context,
    Color primary,
    Color dim,
    FriendsState data,
  ) {
    final friends = data.friends;
    final totalPages = (friends.length / _friendsPerPage).ceil();
    final start = _friendsPage * _friendsPerPage;
    final end = (start + _friendsPerPage).clamp(0, friends.length);
    final pageFriends = friends.sublist(start, end);
    final canPrev = _friendsPage > 0;
    final canNext = _friendsPage < totalPages - 1;
    final c = cardColors(appColor);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: canPrev ? () => setState(() => _friendsPage--) : null,
              child: Opacity(
                opacity: canPrev ? 1.0 : 0.25,
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: c.border,
                  size: Responsive.scale(context, 28),
                ),
              ),
            ),
            SizedBox(width: Responsive.width(context, 8)),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth =
                      (constraints.maxWidth -
                          Responsive.width(context, 6) * 3) /
                      4;
                  final size = cellWidth.clamp(48.0, 100.0);
                  return Wrap(
                    spacing: Responsive.width(context, 6),
                    runSpacing: Responsive.height(context, 10),
                    children: [
                      for (final friend in pageFriends)
                        GestureDetector(
                          onTap: () => showProfileCard(
                            context,
                            uid: friend.uid,
                            appColor: appColor,
                            isOwnProfile: false,
                            onUnfriend: () => ref
                                .read(friendsProvider.notifier)
                                .removeFriend(friend.uid),
                            onBlock: () => ref
                                .read(friendsProvider.notifier)
                                .removeFriend(friend.uid),
                          ),
                          child: SizedBox(
                            width: cellWidth,
                            child: Column(
                              children: [
                                Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: c.border,
                                      width: 2,
                                    ),
                                    color: c.iconBox,
                                  ),
                                  child: ClipOval(
                                    child: friend.pfpBytes != null
                                        ? Image.memory(
                                            friend.pfpBytes!,
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(
                                            Icons.person_rounded,
                                            color: lightenColor(appColor, 0.40),
                                            size: size * 0.5,
                                          ),
                                  ),
                                ),
                                SizedBox(height: Responsive.height(context, 4)),
                                Text(
                                  friend.username,
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 10),
                                    color: c.border,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Add friend slot always appears as the last circle
                      GestureDetector(
                        onTap: () async {
                          await showAddFriendDialog(context, appColor);
                          _refresh();
                        },
                        child: SizedBox(
                          width: cellWidth,
                          child: Column(
                            children: [
                              Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.border, width: 2),
                                  color: c.iconBox,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      color: primary,
                                      size: size * 0.5,
                                    ),
                                    Positioned(
                                      bottom: size * 0.08,
                                      right: size * 0.08,
                                      child: Icon(
                                        Icons.add_rounded,
                                        color: primary,
                                        size: size * 0.28,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: Responsive.height(context, 4)),
                              Text(
                                'Add',
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 10),
                                  color: c.border,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(width: Responsive.width(context, 8)),
            GestureDetector(
              onTap: canNext
                  ? () {
                      setState(() => _friendsPage++);
                      if (data.friendsHasMore &&
                          _friendsPage >=
                              (friends.length / _friendsPerPage) - 1) {
                        ref.read(friendsProvider.notifier).loadMoreFriends();
                      }
                    }
                  : null,
              child: Opacity(
                opacity: canNext ? 1.0 : 0.25,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: c.border,
                  size: Responsive.scale(context, 28),
                ),
              ),
            ),
          ],
        ),
        if (totalPages > 1) ...[
          SizedBox(height: Responsive.height(context, 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              totalPages,
              (i) => Container(
                margin: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 3),
                ),
                width: Responsive.scale(context, i == _friendsPage ? 8 : 5),
                height: Responsive.scale(context, i == _friendsPage ? 8 : 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _friendsPage ? primary : primary.withAlpha(60),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _collapsibleHeader(
    BuildContext context,
    String label,
    int count,
    bool expanded,
    Color primary,
    Color dim, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 11),
              fontWeight: FontWeight.w700,
              color: primary,
              letterSpacing: 1.1,
            ),
          ),
          if (count > 0) ...[
            SizedBox(width: Responsive.width(context, 6)),
            friendsPendingBadge(context, count, appColor),
          ],
          const Spacer(),
          Icon(
            expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: dim,
            size: Responsive.scale(context, 18),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 8)),
      child: Container(height: 1.5, color: cardColors(appColor).border),
    );
  }

  Widget _entryRow(
    BuildContext context,
    FriendEntry entry,
    Color primary,
    Color dim,
    ({
      List<Color> gradient,
      Color border,
      Color iconBox,
      Color iconBorder,
      Color splashColor,
      Color highlightColor,
      Color onCard,
    })
    c, {
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final size = Responsive.scale(context, 38);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(bottom: Responsive.height(context, 10)),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => showProfileCard(
                context,
                uid: entry.uid,
                appColor: appColor,
                isOwnProfile: false,
                onAccept: _refresh,
                onDecline: _refresh,
                onCancelRequest: _refresh,
                onUnfriend: _refresh,
                onBlock: _refresh,
              ),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.iconBox,
                  border: Border.all(color: c.border, width: 1.5),
                ),
                child: ClipOval(
                  child: entry.pfpBytes != null
                      ? Image.memory(entry.pfpBytes!, fit: BoxFit.cover)
                      : Icon(
                          Icons.person_rounded,
                          color: lightenColor(appColor, 0.40),
                          size: Responsive.scale(context, 20),
                        ),
                ),
              ),
            ),
            SizedBox(width: Responsive.width(context, 10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.username,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 13),
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Level ${entry.level}',
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 11),
                      color: dim,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: Responsive.width(context, 8)),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _sectionEmptyState(BuildContext context, Color dim, String message) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 8)),
      child: Text(
        message,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 12),
          color: dim,
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    String label,
    ({
      List<Color> gradient,
      Color border,
      Color iconBox,
      Color iconBorder,
      Color splashColor,
      Color highlightColor,
      Color onCard,
    })
    c, {
    bool muted = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 12),
          vertical: Responsive.height(context, 6),
        ),
        decoration: BoxDecoration(
          gradient: muted
              ? null
              : LinearGradient(
                  colors: c.gradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: muted ? Colors.white.withAlpha(12) : null,
          borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
          border: Border.all(
            color: muted ? Colors.white.withAlpha(30) : c.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 12),
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _loadMoreButton(
    BuildContext context,
    Color primary,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: Responsive.height(context, 8)),
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          'Load more',
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 12),
            color: primary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
