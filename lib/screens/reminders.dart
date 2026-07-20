import 'dart:async';
import 'dart:math';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../globals.dart';
import '../guest.dart';
import '../models/reminder_data.dart';
import '../providers/reminders_provider.dart';
import '../utility/responsive.dart';
import '../services/fcm/notification_service.dart';
import '../services/user_data_manager.dart';
import '../services/voice_search_service.dart';
import '../utility/random_messages.dart';

class Reminders extends ConsumerStatefulWidget {
  const Reminders({super.key});

  @override
  ConsumerState<Reminders> createState() => _RemindersState();
}

class _RemindersState extends ConsumerState<Reminders> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  // Prevent memory leaks
  @override
  void dispose() {
    _voiceSearch.cancel();
    remindersController.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  final VoiceSearchService _voiceSearch = VoiceSearchService();
  final FocusNode _messageFocus = FocusNode();
  bool snackbarActive = false;
  bool isLoading = false; // track the loading state for UI feedback
  late List<String> _ghostMessages = List.generate(
    3,
    (_) => generateReminderPlaceholderMessage(),
  );
  bool _notifBlocked =
      false; // true if OS notifications are denied, used to disable the form
  bool _dateTimePicked = false;
  bool _shakeMessage = false;
  bool _shakeTime = false;
  final TextEditingController remindersController =
      TextEditingController(); // Input text for reminder message
  String reminder = "";
  DateTime dateTime =
      DateTime.now(); // Stores the selected date and time for reminder

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/reminders',
      screenClass: 'Reminders',
    );
    _voiceSearch.init(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Request OS permission if not yet asked, or show blocked dialog if denied
      // Result drives _notifBlocked which disables the form if notifications can't fire
      final granted = await requestNotificationPermissionIfNeeded(
        context,
        ref.read(userDataProvider.notifier),
        appColor: appColor,
        message:
            'Enable notifications for Level Up! in your device settings to receive your reminders.',
      );
      if (!mounted) return;
      setState(() => _notifBlocked = !granted);
      if (!isGuest &&
          ref.read(userDataProvider).value?.notificationsEnabled == false) {
        _showNotificationsDisabledDialog(); // in-app toggle is off, prompt to re-enable
      }
    });
  }

  void _showNotificationsDisabledDialog() {
    showFrostedAlertDialog(
      context: context,
      appColor: appColor,
      title: "In-App Notifications Are Disabled",
      content: Text("Enable notifications to receive reminders."),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text("Dismiss", style: dialogButtonStyle()),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(
              context,
              rootNavigator: true,
            ).pop(); // close dialog first
            await ref
                .read(userDataProvider.notifier)
                .updateNotificationsEnabled(true, context);

            if (kIsWeb) {
              final token = await requestNotificationAndToken();
              if (token != null) {
                await ref.read(userDataProvider.notifier).addFcmToken(token);
              } else if (mounted) {
                showBrowserBlockedDialog(
                  context,
                  ref.read(userDataProvider.notifier),
                  appColor: appColor,
                ); // fallback dialog
              }
            }
          },
          child: Text("Enable", style: dialogButtonStyle(confirm: true)),
        ),
      ],
    );
  }

  // Toggles the microphone for voice input on the reminder message field
  Future<void> _toggleListening() async {
    if (!_voiceSearch.isAvailable) return;
    // snapshot text before listening so new results append rather than replace
    final textBeforeListen = remindersController.text;
    await _voiceSearch.toggle((text) {
      final combined = textBeforeListen.isEmpty
          ? text
          : '${textBeforeListen.trimRight()} $text';
      remindersController.text = combined;
      remindersController.selection = TextSelection.fromPosition(
        TextPosition(offset: combined.length),
      );
      setState(() => reminder = combined);
    });
    if (mounted) setState(() {}); // update mic icon state after listening stops
  }

  // Method that deletes a reminder from the Supabase Postgres db
  Future<void> _deleteReminder(ReminderData reminder) async {
    if (isGuest) {
      Guest.block(
        context,
        title: 'Sign up to set reminders',
        description:
            'Create a free account to set custom reminders and never miss a habit.',
      );
      return;
    } // For guest users
    final confirmed = await showFrostedAlertDialog<bool>(
      context: context,
      appColor: appColor,
      title: "Delete reminder?",
      content: Text(
        '"${reminder.message}"',
        style: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: Responsive.font(context, 13),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: Text("Cancel", style: dialogButtonStyle()),
        ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: Text("Delete", style: dialogButtonStyle(confirm: true)),
        ),
      ],
    );
    if (confirmed != true) return;
    try {
      final success = await ref
          .read(remindersProvider.notifier)
          .deleteReminder(reminder);
      if (mounted) {
        if (success) {
          _showSnackbar("Reminder deleted.");
        } else {
          _showSnackbar("Failed to delete reminder.", isError: true);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error deleting reminder: $e");
      if (mounted) _showSnackbar("Failed to delete reminder.", isError: true);
    }
  }

  Widget _buildGhostCard(String message) {
    return frostedGlassCard(
      context,
      color: appColor,
      baseRadius: 16,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 12),
      ),
      child: Row(
        children: [
          themedIconBox(
            context,
            icon: HugeIcons.strokeRoundedNotification01,
            color: appColor,
            iconSize: 16,
            padding: 7,
            circle: true,
            hugeIcon: true,
          ),
          SizedBox(width: Responsive.width(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 14),
                    color: onTheme(appColor),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: Responsive.width(context, 8)),
          GestureDetector(
            onTap: () => _showQuickReminderDialog(message),
            child: Container(
              width: Responsive.scale(context, 34),
              height: Responsive.scale(context, 34),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cardColors(appColor).iconBox,
                border: Border.all(
                  color: cardColors(appColor).iconBorder,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.edit_outlined,
                color: onTheme(appColor),
                size: Responsive.scale(context, 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQuickReminderDialog(String prefillMessage) async {
    if (isGuest) {
      Guest.block(
        context,
        title: 'Sign up to set reminders',
        description:
            'Create a free account to set custom reminders and never miss a habit.',
      );
      return;
    }
    final msgController = TextEditingController(text: prefillMessage);
    DateTime pickedTime = DateTime.now();
    bool submitting = false;

    await showFrostedDialog(
      context: context,
      appColor: appColor,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Quick Reminder',
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 16),
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: Responsive.height(context, 12)),
              TextField(
                controller: msgController,
                maxLength: 200,
                maxLines: 3,
                minLines: 1,
                onChanged: (_) => setDialogState(() {}),
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 14),
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  counterStyle: GoogleFonts.manrope(
                    color: onTheme(appColor).withAlpha(100),
                    fontSize: Responsive.font(context, 10),
                  ),
                  suffixIcon: msgController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            msgController.clear();
                            setDialogState(() {});
                          },
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: Responsive.width(context, 12),
                            ),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedCancel01,
                              color: onTheme(appColor).withAlpha(140),
                              size: Responsive.scale(context, 18),
                            ),
                          ),
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(),
                  hintText: 'Reminder message...',
                  hintStyle: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 14),
                    color: onTheme(appColor).withAlpha(100),
                  ),
                  filled: true,
                  fillColor: Colors.white.withAlpha(10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 12),
                    ),
                    borderSide: BorderSide(color: cardColors(appColor).border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 12),
                    ),
                    borderSide: BorderSide(
                      color: Colors.white.withAlpha(180),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 14),
                    vertical: Responsive.height(context, 12),
                  ),
                ),
              ),
              SizedBox(height: Responsive.height(context, 12)),
              SizedBox(
                height: Responsive.height(context, 180),
                child: CupertinoDatePicker(
                  initialDateTime: pickedTime,
                  minimumDate: DateTime.now().subtract(
                    const Duration(minutes: 1),
                  ),
                  mode: CupertinoDatePickerMode.dateAndTime,
                  use24hFormat: false,
                  onDateTimeChanged: (d) =>
                      setDialogState(() => pickedTime = d),
                ),
              ),
              SizedBox(height: Responsive.height(context, 8)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                    child: Text('Cancel', style: dialogButtonStyle()),
                  ),
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final msg = msgController.text.trim();
                            if (msg.isEmpty) return;
                            setDialogState(() => submitting = true);
                            final id = Random().nextInt(0x7fffffff);
                            final success = await ref
                                .read(remindersProvider.notifier)
                                .addReminder(
                                  message: msg,
                                  scheduledAt: pickedTime,
                                  notificationId: id,
                                );
                            if (!mounted) return;
                            Navigator.of(context, rootNavigator: true).pop();
                            if (success) {
                              _showSnackbar('Reminder set!');
                            } else {
                              _showSnackbar(
                                'Failed to set reminder.',
                                isError: true,
                              );
                            }
                          },
                    child: Text(
                      'Set Reminder',
                      style: dialogButtonStyle(confirm: true),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    msgController.dispose();
  }

  Future<void> pickDateTime(
    BuildContext context,
    DateTime dateTime,
    Function(DateTime) onPicked,
  ) async {
    await showFrostedDialog(
      context: context,
      appColor: appColor,
      child: SizedBox(
        height: Responsive.height(context, 300),
        width: Responsive.width(context, 400),
        child: Column(
          children: [
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime: dateTime,
                minimumDate: DateTime.now().subtract(
                  const Duration(minutes: 1),
                ),
                mode: CupertinoDatePickerMode.dateAndTime,
                use24hFormat: false,
                onDateTimeChanged: (newDate) => onPicked(newDate),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  child: Text("Cancel", style: dialogButtonStyle()),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    _setReminder();
                  },
                  child: Text(
                    "Set Reminder",
                    style: dialogButtonStyle(confirm: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Snackbar helper method
  void _showSnackbar(String message, {bool isError = false}) {
    if (snackbarActive) return; // Prevent multiple snackbars
    snackbarActive = true; // Mark as active

    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedInformationCircle,
                  color: Colors.white,
                  size: Responsive.scale(context, 18),
                ),
                SizedBox(width: Responsive.width(context, 10)),
                Expanded(child: Text(message, softWrap: true)),
              ],
            ),
          ),
        )
        .closed
        .then((_) => snackbarActive = false);
  }

  // Method that saves a new reminder to the Supabase Postgres db
  Future<void> _setReminder() async {
    if (isGuest) {
      Guest.block(
        context,
        title: 'Sign up to set reminders',
        description:
            'Create a free account to set custom reminders and never miss a habit.',
      );
      return;
    } // For guest users
    if (isLoading) return;

    if (remindersController.text.trim().isEmpty) {
      setState(() => _shakeMessage = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _shakeMessage = false);
      });
      _showSnackbar("Enter a reminder message first.", isError: true);
      return;
    }

    if (!_dateTimePicked) {
      setState(() => _shakeTime = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _shakeTime = false);
      });
      return;
    }

    final pickedTime = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
    );

    if (pickedTime.isBefore(DateTime.now())) {
      _showSnackbar("Reminders must be in the future!", isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final id = Random().nextInt(0x7fffffff);
      final message = remindersController.text;

      final success = await ref
          .read(remindersProvider.notifier)
          .addReminder(
            message: message,
            scheduledAt: pickedTime,
            notificationId: id,
          );

      if (!success) {
        _showSnackbar("Failed to set reminder.", isError: true);
        return;
      }

      _showSnackbar("Reminder set successfully!");
      remindersController.clear();
      setState(() => _dateTimePicked = false);

      // Track future_reminder if the reminder is 1+ month out
      if (pickedTime.isAfter(DateTime.now().add(const Duration(days: 30)))) {
        trackTrivialAchievement("future_reminder");
      }
      // Track active_reminders if the user now has 5+ active reminders
      final reminders = ref.read(remindersProvider).value ?? [];
      if (reminders.length >= 5) {
        trackTrivialAchievement("active_reminders");
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error in _setReminder: $e");
      _showSnackbar("Failed to set reminder: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Formats DateTime into a readable label
  String _formatDateTime(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    final weekday = weekdays[dt.weekday - 1];
    final month = months[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$weekday, $month ${dt.day} · $hour:$minute $period';
  }

  // Makes a single reminder card with message, time, delete button, and countdown
  Widget _buildReminderCard(
    ReminderData reminder, {
    bool showCountdown = false,
    bool isSoonest = false,
  }) {
    final timeLeft = reminder.scheduledAt.difference(DateTime.now());
    String? countdownLabel;
    if (showCountdown && !timeLeft.isNegative) {
      if (timeLeft.inMinutes < 1) {
        countdownLabel = 'in ${timeLeft.inSeconds}s';
      } else if (timeLeft.inMinutes < 60) {
        countdownLabel = 'in ${timeLeft.inMinutes}m';
      } else if (timeLeft.inHours < 24) {
        countdownLabel = 'in ${timeLeft.inHours}h ${timeLeft.inMinutes % 60}m';
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 10)),
      child: frostedGlassCard(
        context,
        color: appColor,
        baseRadius: 16,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 16),
          vertical: Responsive.height(context, 12),
        ),
        child: Row(
          children: [
            themedIconBox(
              context,
              icon: HugeIcons.strokeRoundedNotification01,
              color: appColor,
              iconSize: 16,
              padding: 7,
              circle: false,
              hugeIcon: true,
            ),
            SizedBox(width: Responsive.width(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 14),
                      color: onTheme(appColor),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: Responsive.height(context, 2)),
                  Row(
                    children: [
                      Text(
                        _formatDateTime(reminder.scheduledAt),
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 11),
                          color: onTheme(appColor).withAlpha(140),
                        ),
                      ),
                      if (countdownLabel != null) ...[
                        SizedBox(width: Responsive.width(context, 6)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 6),
                            vertical: Responsive.height(context, 2),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 8),
                            ),
                            border: Border.all(
                              color: cardColors(appColor).border,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            countdownLabel,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 10),
                              color: onTheme(appColor).withAlpha(140),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _deleteReminder(reminder),
              child: Padding(
                padding: EdgeInsets.only(left: Responsive.width(context, 8)),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedDelete02,
                  color: onTheme(appColor).withAlpha(140),
                  size: Responsive.scale(context, 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              AppRefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(remindersProvider);
                }, // no manual refresh method, invalidate triggers auto-fetch on next read
                appColor: appColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: Responsive.centeredHorizontalPadding(context, 50),
                      right: Responsive.centeredHorizontalPadding(context, 50),
                      bottom: Responsive.height(context, 24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: Responsive.height(context, 8),
                            bottom: Responsive.height(context, 12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              themedIconBox(
                                context,
                                icon: Icons.arrow_back_ios_new,
                                color: appColor,
                                iconSize: 13,
                                padding: 12,
                                circle: true,
                                onTap: () => context.pop(),
                              ),
                              if (kIsWeb)
                                GestureDetector(
                                  onTap: () => showFrostedAlertDialog(
                                    context: context,
                                    appColor: appColor,
                                    title: "Notifications not working?",
                                    content: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "All three must be enabled:",
                                          style: GoogleFonts.manrope(
                                            fontSize: Responsive.font(
                                              context,
                                              13,
                                            ),
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            height: 1.5,
                                          ),
                                        ),
                                        SizedBox(
                                          height: Responsive.height(context, 8),
                                        ),
                                        Text(
                                          "1) In-app notifications\n2) Browser notification permissions\n3) Browser notifications in your system settings",
                                          style: GoogleFonts.manrope(
                                            fontSize: Responsive.font(
                                              context,
                                              13,
                                            ),
                                            color: Colors.white,
                                            height: 1.6,
                                          ),
                                        ),
                                        SizedBox(
                                          height: Responsive.height(
                                            context,
                                            12,
                                          ),
                                        ),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            HugeIcon(
                                              icon: HugeIcons
                                                  .strokeRoundedSmartPhone01,
                                              color: Colors.white.withAlpha(
                                                140,
                                              ),
                                              size: Responsive.scale(
                                                context,
                                                18,
                                              ),
                                            ),
                                            SizedBox(
                                              width: Responsive.width(
                                                context,
                                                10,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                "iPhone users must install Level Up! as a PWA (Add to Home Screen) for notifications to work.",
                                                style: GoogleFonts.manrope(
                                                  fontSize: Responsive.font(
                                                    context,
                                                    13,
                                                  ),
                                                  color: Colors.white,
                                                  height: 1.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      Expanded(
                                        child: Center(
                                          child: TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                              rootNavigator: true,
                                            ).pop(),
                                            child: Text(
                                              "Dismiss",
                                              style: GoogleFonts.manrope(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    width: Responsive.scale(context, 37),
                                    height: Responsive.scale(context, 37),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cardColors(appColor).iconBox,
                                      border: Border.all(
                                        color: cardColors(appColor).iconBorder,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "?",
                                        style: GoogleFonts.manrope(
                                          color: onTheme(appColor),
                                          fontSize: Responsive.font(
                                            context,
                                            15,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        sectionHeader(
                          "REMINDER DETAILS",
                          context,
                          appColor: appColor,
                        ),
                        // Unified composer card
                        frostedGlassCard(
                          context,
                          color: appColor,
                          baseRadius: 20,
                          border: Border.all(
                            color: cardColors(appColor).border.withAlpha(180),
                            width: 1.5,
                          ),
                          padding: EdgeInsets.all(
                            Responsive.scale(context, 16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Message row
                              // Message field
                              TextField(
                                enabled: !_notifBlocked,
                                maxLines: 2,
                                minLines: 1,
                                maxLength: 200,
                                controller: remindersController,
                                focusNode: _messageFocus,
                                keyboardType: TextInputType.text,
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 14),
                                  color: onTheme(appColor),
                                ),
                                decoration: InputDecoration(
                                  counterStyle: GoogleFonts.manrope(
                                    color: onTheme(appColor).withAlpha(100),
                                    fontSize: Responsive.font(context, 10),
                                  ),
                                  suffixIcon:
                                      !isGuest && _voiceSearch.isAvailable
                                      ? GestureDetector(
                                          onTap: _toggleListening,
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right: Responsive.width(
                                                context,
                                                12,
                                              ),
                                            ),
                                            child: HugeIcon(
                                              icon: _voiceSearch.isListening
                                                  ? HugeIcons.strokeRoundedMic01
                                                  : HugeIcons
                                                        .strokeRoundedMic02,
                                              color: _voiceSearch.isListening
                                                  ? onTheme(appColor)
                                                  : onTheme(
                                                      appColor,
                                                    ).withAlpha(140),
                                              size: Responsive.scale(
                                                context,
                                                18,
                                              ),
                                            ),
                                          ),
                                        )
                                      : null,
                                  suffixIconConstraints: const BoxConstraints(),
                                  hintText: 'Enter reminder message...',
                                  hintStyle: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 14),
                                    color: onTheme(appColor).withAlpha(100),
                                  ),
                                  filled: true,
                                  fillColor: _shakeMessage
                                      ? onTheme(appColor).withAlpha(15)
                                      : Colors.white.withAlpha(10),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      Responsive.scale(context, 12),
                                    ),
                                    borderSide: BorderSide(
                                      color: _shakeMessage
                                          ? onTheme(appColor).withAlpha(200)
                                          : cardColors(appColor).border,
                                      width: _shakeMessage ? 1.5 : 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      Responsive.scale(context, 12),
                                    ),
                                    borderSide: BorderSide(
                                      color: onTheme(appColor).withAlpha(180),
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: Responsive.width(context, 14),
                                    vertical: Responsive.height(context, 12),
                                  ),
                                ),
                                onChanged: (v) => setState(() => reminder = v),
                              ),
                              SizedBox(height: Responsive.height(context, 10)),
                              // Time picker button
                              GestureDetector(
                                onTap: _notifBlocked
                                    ? null
                                    : () => pickDateTime(
                                        context,
                                        dateTime,
                                        (d) => setState(() {
                                          dateTime = d;
                                          _dateTimePicked = true;
                                        }),
                                      ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    vertical: Responsive.height(context, 13),
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: _shakeTime
                                        ? null
                                        : LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: cardColors(
                                              appColor,
                                            ).gradient,
                                          ),
                                    color: _shakeTime
                                        ? onTheme(appColor).withAlpha(15)
                                        : null,
                                    borderRadius: BorderRadius.circular(
                                      Responsive.scale(context, 12),
                                    ),
                                    border: Border.all(
                                      color: _shakeTime
                                          ? onTheme(appColor).withAlpha(200)
                                          : cardColors(appColor).border,
                                      width: _shakeTime ? 1.5 : 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      HugeIcon(
                                        icon: HugeIcons.strokeRoundedClock01,
                                        color: onTheme(appColor),
                                        size: Responsive.scale(context, 16),
                                      ),
                                      SizedBox(
                                        width: Responsive.width(context, 8),
                                      ),
                                      Text(
                                        _dateTimePicked
                                            ? _formatDateTime(dateTime)
                                            : 'Set a time',
                                        style: GoogleFonts.manrope(
                                          fontSize: Responsive.font(
                                            context,
                                            13,
                                          ),
                                          color: onTheme(appColor),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (isLoading) ...[
                                        SizedBox(
                                          width: Responsive.width(context, 10),
                                        ),
                                        SizedBox(
                                          width: Responsive.scale(context, 14),
                                          height: Responsive.scale(context, 14),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: onTheme(
                                              appColor,
                                            ).withAlpha(160),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              // Quick-time chips: context-aware based on current time
                              Builder(
                                builder: (context) {
                                  final now = DateTime.now();
                                  // round up to the next clean hour
                                  final nextHour = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    now.hour + 1,
                                  );
                                  final in30m = now.add(
                                    const Duration(minutes: 30),
                                  );
                                  final in1h = nextHour;
                                  final in3h = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    now.hour + 3,
                                  );
                                  // tonight = 9PM if before 9PM, else skip
                                  final tonight9 = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    21,
                                  );
                                  // tomorrow morning = 8AM
                                  final tomorrowAM = DateTime(
                                    now.year,
                                    now.month,
                                    now.day + 1,
                                    8,
                                  );
                                  // tomorrow noon
                                  final tomorrowNoon = DateTime(
                                    now.year,
                                    now.month,
                                    now.day + 1,
                                    12,
                                  );

                                  String fmtHour(DateTime dt) {
                                    final h = dt.hour % 12 == 0
                                        ? 12
                                        : dt.hour % 12;
                                    final m = dt.minute.toString().padLeft(
                                      2,
                                      '0',
                                    );
                                    final p = dt.hour < 12 ? 'AM' : 'PM';
                                    return m == '00' ? '$h$p' : '$h:$m$p';
                                  }

                                  final chips = <(String, DateTime)>[
                                    ('In 30m · ${fmtHour(in30m)}', in30m),
                                    ('In 1h · ${fmtHour(in1h)}', in1h),
                                    ('In 3h · ${fmtHour(in3h)}', in3h),
                                    if (tonight9.isAfter(now))
                                      ('Tonight · 9PM', tonight9),
                                    ('Tomorrow · 8AM', tomorrowAM),
                                    ('Tomorrow · 12PM', tomorrowNoon),
                                  ];

                                  // 3-column grid so chips fill the width evenly
                                  final rows = <List<(String, DateTime)>>[];
                                  for (int i = 0; i < chips.length; i += 3) {
                                    rows.add(
                                      chips.sublist(
                                        i,
                                        i + 3 > chips.length
                                            ? chips.length
                                            : i + 3,
                                      ),
                                    );
                                  }

                                  return Padding(
                                    padding: EdgeInsets.only(
                                      top: Responsive.height(context, 10),
                                    ),
                                    child: Column(
                                      children: [
                                        for (final row in rows) ...[
                                          Row(
                                            children: [
                                              for (
                                                int i = 0;
                                                i < row.length;
                                                i++
                                              ) ...[
                                                if (i > 0)
                                                  SizedBox(
                                                    width: Responsive.width(
                                                      context,
                                                      8,
                                                    ),
                                                  ),
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        dateTime = row[i].$2;
                                                        _dateTimePicked = true;
                                                      });
                                                      if (remindersController
                                                          .text
                                                          .trim()
                                                          .isNotEmpty) {
                                                        _setReminder();
                                                      }
                                                    },
                                                    child: AnimatedContainer(
                                                      duration: const Duration(
                                                        milliseconds: 150,
                                                      ),
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            vertical:
                                                                Responsive.height(
                                                                  context,
                                                                  8,
                                                                ),
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            _dateTimePicked &&
                                                                dateTime ==
                                                                    row[i].$2
                                                            ? onTheme(
                                                                appColor,
                                                              ).withAlpha(180)
                                                            : onTheme(
                                                                appColor,
                                                              ).withAlpha(15),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              Responsive.scale(
                                                                context,
                                                                10,
                                                              ),
                                                            ),
                                                        border: Border.all(
                                                          color: onTheme(
                                                            appColor,
                                                          ).withAlpha(40),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        row[i].$1,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: GoogleFonts.manrope(
                                                          fontSize:
                                                              Responsive.font(
                                                                context,
                                                                11,
                                                              ),
                                                          color:
                                                              _dateTimePicked &&
                                                                  dateTime ==
                                                                      row[i].$2
                                                              ? cardColors(
                                                                  appColor,
                                                                ).iconBox
                                                              : onTheme(
                                                                  appColor,
                                                                ).withAlpha(
                                                                  160,
                                                                ),
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (row != rows.last)
                                            SizedBox(
                                              height: Responsive.height(
                                                context,
                                                8,
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: Responsive.height(context, 28)),

                        // Reminder list or empty state
                        Builder(
                          builder: (context) {
                            final remindersAsync = ref.watch(remindersProvider);
                            final isLoading = remindersAsync.isLoading;
                            final reminders = remindersAsync.value ?? [];

                            final headerLabel =
                                reminders.isEmpty && !(isLoading && !isGuest)
                                ? "SET YOUR FIRST REMINDER"
                                : "UPCOMING REMINDERS";

                            if (!isGuest && isLoading) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  sectionHeader(
                                    headerLabel,
                                    context,
                                    appColor: appColor,
                                  ),
                                  Skeletonizer(
                                    effect: ShimmerEffect(
                                      baseColor: cardColors(appColor).iconBox,
                                      highlightColor: cardColors(
                                        appColor,
                                      ).border,
                                      duration: const Duration(
                                        milliseconds: 1200,
                                      ),
                                    ),
                                    child: Column(
                                      children: List.generate(
                                        3,
                                        (_) => _buildReminderCard(
                                          ReminderData(
                                            id: 'placeholder',
                                            message:
                                                'Loading reminder message here',
                                            scheduledAt: DateTime.now(),
                                            notificationId: 0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            if (reminders.isEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: sectionHeader(
                                          headerLabel,
                                          context,
                                          appColor: appColor,
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom: Responsive.height(
                                            context,
                                            12,
                                          ),
                                        ),
                                        child: GestureDetector(
                                          onTap: () => setState(() {
                                            _ghostMessages = List.generate(
                                              3,
                                              (_) =>
                                                  generateReminderPlaceholderMessage(),
                                            );
                                          }),
                                          child: themedIconBox(
                                            context,
                                            icon:
                                                HugeIcons.strokeRoundedRefresh,
                                            color: appColor,
                                            iconSize: 14,
                                            padding: 6,
                                            radius: 8,
                                            hugeIcon: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  for (final msg in _ghostMessages)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        bottom: Responsive.height(context, 10),
                                      ),
                                      child: Opacity(
                                        opacity: 0.65,
                                        child: _buildGhostCard(msg),
                                      ),
                                    ),
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                sectionHeader(
                                  headerLabel,
                                  context,
                                  appColor: appColor,
                                ),
                                for (int i = 0; i < reminders.length; i++)
                                  _buildReminderCard(
                                    reminders[i],
                                    showCountdown: true,
                                    isSoonest: i == 0,
                                  ),
                              ],
                            );
                          },
                        ),

                        SizedBox(height: Responsive.height(context, 40)),
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
