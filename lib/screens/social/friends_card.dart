import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../globals.dart';
import '../../utility/responsive.dart';
import '../../services/user_data_manager.dart'
    show authenticatedGet, authenticatedPost;

class _UserSearchResult {
  final String uid;
  final String username;
  final int level;
  final Uint8List? pfpBytes;
  final bool isPremium;
  final String friendshipStatus;

  _UserSearchResult({
    required this.uid,
    required this.username,
    required this.level,
    this.pfpBytes,
    this.isPremium = false,
    this.friendshipStatus = 'none',
  });

  factory _UserSearchResult.fromJson(Map<String, dynamic> json) {
    Uint8List? pfp;
    if (json['pfp_base64'] != null) {
      pfp = base64Decode(json['pfp_base64'] as String);
    }
    return _UserSearchResult(
      uid: json['uid'] as String,
      username: json['username'] as String,
      level: json['level'] as int,
      pfpBytes: pfp,
      isPremium: json['is_premium'] as bool? ?? false,
      friendshipStatus: json['friendship_status'] as String? ?? 'none',
    );
  }
}

Widget friendsPendingBadge(BuildContext context, int count, Color appColor) {
  final c = cardColors(appColor);
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: Responsive.width(context, 7),
      vertical: Responsive.height(context, 2),
    ),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: c.gradient),
      borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
      border: Border.all(color: c.border, width: 1),
    ),
    child: Text(
      '$count',
      style: GoogleFonts.manrope(
        fontSize: Responsive.font(context, 11),
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

// Shared scaffold for username search dialogs with title, subtitle, text field, and Cancel/confirm buttons
// Extra content (e.g. search results) goes in [extra], which receives the StatefulBuilder setState
Future<void> showUsernameDialog({
  required BuildContext context,
  required Color appColor,
  required String title,
  required String subtitle,
  required String confirmLabel,
  required Future<void> Function(
    String query,
    void Function(void Function()) setState,
    BuildContext ctx,
  )
  onConfirm,
  Widget Function(void Function(void Function()) setState, BuildContext ctx)?
  extra,
}) async {
  final controller = TextEditingController();

  await showFrostedDialog(
    context: context,
    appColor: appColor,
    child: StatefulBuilder(
      builder: (ctx, setState) {
        final c = cardColors(appColor);

        Future<void> doConfirm() async {
          if (controller.text.trim().isEmpty) return;
          await onConfirm(controller.text.trim(), setState, ctx);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(ctx, 16),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Responsive.height(ctx, 4)),
            Text(
              subtitle,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(ctx, 12),
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Responsive.height(ctx, 16)),
            TextField(
              controller: controller,
              maxLength: 20,
              autofocus: true,
              cursorColor: Colors.white,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: Responsive.font(ctx, 14),
              ),
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(
                hintText: 'Username',
                hintStyle: GoogleFonts.manrope(
                  color: Colors.white38,
                  fontSize: Responsive.font(ctx, 14),
                ),
                filled: true,
                fillColor: Colors.white.withAlpha(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(ctx, 10),
                  ),
                  borderSide: BorderSide(color: Colors.white.withAlpha(25)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(ctx, 10),
                  ),
                  borderSide: BorderSide(color: Colors.white.withAlpha(25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(ctx, 10),
                  ),
                  borderSide: BorderSide(color: c.border, width: 1.5),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(ctx, 12),
                  vertical: Responsive.height(ctx, 12),
                ),
              ),
              onSubmitted: (_) => doConfirm(),
            ),
            if (extra != null) extra(setState, ctx),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.of(ctx, rootNavigator: true).pop(),
                    child: Text('Cancel', style: dialogButtonStyle()),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: doConfirm,
                    child: Text(
                      confirmLabel,
                      style: dialogButtonStyle(confirm: true),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

Future<void> showAddFriendDialog(BuildContext context, Color appColor) async {
  _UserSearchResult? searchResult;
  bool searched = false;
  bool isSelf = false;
  String addState = 'none';

  Future<void> doSearch(
    String query,
    void Function(void Function()) setState,
    BuildContext ctx,
  ) async {
    setState(() {
      searched = false;
      isSelf = false;
      addState = 'none';
    });
    final res = await authenticatedGet(
      'search_user?username=${Uri.encodeComponent(query)}',
    );
    if (!ctx.mounted) return;
    _UserSearchResult? result;
    final self =
        res.statusCode == 400 &&
        (jsonDecode(res.body) as Map)['error'] == 'self_search';
    if (res.statusCode == 200) {
      result = _UserSearchResult.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    final initialState = switch (result?.friendshipStatus) {
      'accepted' => 'friends',
      'pending_sent' || 'pending_received' => 'pending',
      _ => 'none',
    };
    setState(() {
      searched = true;
      searchResult = result;
      isSelf = self;
      addState = initialState;
    });
  }

  await showUsernameDialog(
    context: context,
    appColor: appColor,
    title: 'Add a Friend',
    subtitle: 'Search by exact username',
    confirmLabel: 'Search',
    onConfirm: doSearch,
    extra: (setState, ctx) {
      final primary = lightenColor(appColor, 0.45);
      final dim = lightenColor(appColor, 0.30);

      return AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutQuart,
        child: searched
            ? Padding(
                padding: EdgeInsets.only(top: Responsive.height(ctx, 16)),
                child: searchResult != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _searchResultTile(
                            ctx,
                            searchResult!,
                            appColor,
                            primary,
                            dim,
                            addState: addState,
                            onAdd: () async {
                              final res = await authenticatedPost(
                                'friends/request',
                                body: {
                                  'target_uid': searchResult!.uid,
                                  'action': 'send',
                                },
                              );
                              if (!ctx.mounted) return;
                              final body =
                                  jsonDecode(res.body) as Map<String, dynamic>;
                              final reason = body['reason'] as String?;
                              if (reason == 'already_friends') {
                                setState(() => addState = 'friends');
                                return;
                              }
                              if (reason == 'request_already_exists') {
                                setState(() => addState = 'pending');
                                return;
                              }
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Friend request sent to ${searchResult!.username}',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                      ),
                                    ),
                                    duration: snackBarDuration,
                                  ),
                                );
                              }
                              Navigator.of(ctx, rootNavigator: true).pop();
                            },
                            onCancelRequest: () async {
                              await authenticatedPost(
                                'friends/request',
                                body: {
                                  'target_uid': searchResult!.uid,
                                  'action': 'cancel',
                                },
                              );
                              if (!ctx.mounted) return;
                              setState(() => addState = 'none');
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Friend request cancelled',
                                    style: GoogleFonts.manrope(
                                      color: Colors.white,
                                    ),
                                  ),
                                  duration: snackBarDuration,
                                ),
                              );
                            },
                            onUnfriend: () async {
                              final confirmed = await showHoldToConfirmDialog(
                                context: ctx,
                                appColor: appColor,
                                title: 'Unfriend ${searchResult!.username}?',
                                subtitle:
                                    'You will need to send a new friend request to reconnect.',
                                icon: HugeIcons.strokeRoundedUserRemove01,
                              );
                              if (confirmed != true || !ctx.mounted) return;
                              await authenticatedPost(
                                'friends/unfriend',
                                body: {'target_uid': searchResult!.uid},
                              );
                              if (!ctx.mounted) return;
                              setState(() => addState = 'none');
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Removed ${searchResult!.username} from friends',
                                    style: GoogleFonts.manrope(
                                      color: Colors.white,
                                    ),
                                  ),
                                  duration: snackBarDuration,
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    : Text(
                        isSelf
                            ? "You can't add yourself."
                            : 'No user found with that username.',
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(ctx, 13),
                          color: dim,
                        ),
                        textAlign: TextAlign.center,
                      ),
              )
            : const SizedBox.shrink(),
      );
    },
  );
}

Widget _searchResultTile(
  BuildContext ctx,
  _UserSearchResult user,
  Color appColor,
  Color primary,
  Color dim, {
  required String addState,
  required VoidCallback onAdd,
  required VoidCallback onCancelRequest,
  required VoidCallback onUnfriend,
}) {
  final c = cardColors(appColor);
  final size = Responsive.scale(ctx, 40);

  final String buttonLabel;
  final VoidCallback buttonAction;
  final bool muted;
  if (addState == 'friends') {
    buttonLabel = 'Unfriend';
    buttonAction = onUnfriend;
    muted = true;
  } else if (addState == 'pending') {
    buttonLabel = 'Cancel';
    buttonAction = onCancelRequest;
    muted = true;
  } else {
    buttonLabel = 'Add';
    buttonAction = onAdd;
    muted = false;
  }

  return Row(
    children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.iconBox,
          border: Border.all(color: c.border, width: 1.5),
        ),
        child: ClipOval(
          child: user.pfpBytes != null
              ? Image.memory(user.pfpBytes!, fit: BoxFit.cover)
              : Icon(
                  Icons.person_rounded,
                  color: primary,
                  size: Responsive.scale(ctx, 20),
                ),
        ),
      ),
      SizedBox(width: Responsive.width(ctx, 12)),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.username,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(ctx, 14),
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
            Text(
              'Level ${user.level}',
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(ctx, 11),
                color: dim,
              ),
            ),
          ],
        ),
      ),
      GestureDetector(
        onTap: buttonAction,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(ctx, 12),
            vertical: Responsive.height(ctx, 7),
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
            borderRadius: BorderRadius.circular(Responsive.scale(ctx, 20)),
            border: Border.all(
              color: muted ? Colors.white.withAlpha(30) : c.border,
              width: 1.5,
            ),
          ),
          child: Text(
            buttonLabel,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(ctx, 13),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ],
  );
}
