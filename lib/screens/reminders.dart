import 'dart:math';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../globals.dart';
import '../guest.dart';
import '../models/reminder_data.dart';
import '../utility/responsive.dart';
import '../services/fcm/notification_service.dart';
import '../services/user_data_manager.dart';

class Reminders extends StatefulWidget {
  const Reminders({super.key});

  @override
  State<Reminders> createState() => _RemindersState();
}

class _RemindersState extends State<Reminders> {
  // Prevent memory leaks
  @override
  void dispose() {
    remindersController.dispose();
    super.dispose();
  }

  bool snackbarActive = false;
  bool isLoading = false; // track the loading state for UI feedback
  bool _notifBlocked =
      false; // true if OS notifications are denied, used to disable the form
  bool _dateTimePicked = false;
  final TextEditingController remindersController =
      TextEditingController(); // Input text for reminder message
  String reminder = "";
  String placeholderMessage = "";
  DateTime dateTime =
      DateTime.now(); // Stores the selected date and time for reminder

  List<ReminderData> reminders =
      []; // Local list to store reminders for UI display

  @override
  void initState() {
    super.initState();
    reminders = List.from(
      currentUserData?.reminders ?? [],
    ); // show cached data instantly
    placeholderMessage = getReminderMessage();
    _loadRemindersFromServer(); // refresh from server in the background
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Request OS permission if not yet asked, or show blocked dialog if denied
      // Result drives _notifBlocked which disables the form if notifications can't fire
      final granted = await requestNotificationPermissionIfNeeded(context);
      if (!mounted) return;
      setState(() => _notifBlocked = !granted);
      if (currentUserData?.notificationsEnabled == false) {
        _showNotificationsDisabledDialog(); // in-app toggle is off, prompt to re-enable
      }
    });
  }

  void _showNotificationsDisabledDialog() {
    showFrostedAlertDialog(
      context: context,
      title: "In-App Notifications Are Disabled",
      content: Text("Enable notifications to receive reminders."),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text("Dismiss"),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(
              context,
              rootNavigator: true,
            ).pop(); // close dialog first
            await userManager.updateNotificationsEnabled(true, context);

            if (kIsWeb) {
              final token = await requestNotificationAndToken();
              if (token != null) {
                await userManager.addFcmToken(token);
              } else if (mounted) {
                showBrowserBlockedDialog(context); // fallback dialog
              }
            }
          },
          child: Text("Enable"),
        ),
      ],
    );
  }

  Future<void> _loadRemindersFromServer() async {
    try {
      final result = await _loadReminders();

      if (!mounted) return;

      setState(() {
        reminders = result;
      });
    } catch (e) {
      if (kDebugMode) debugPrint("Failed to load reminders: $e");
    }
  }

  // Loads reminders from the Supabase Postgres db and removes past ones
  Future<List<ReminderData>> _loadReminders() async {
    final response = await authenticatedGet('reminders');

    if (response.statusCode != 200) {
      throw Exception('getReminders failed: ${response.body}');
    }

    final List data = jsonDecode(response.body)['reminders'];

    return data.map((r) => ReminderData.fromJson(r)).toList();
  }

  // Method to generate a few random reminder messages for the placeholder text using grammar rules to make them more natural and less repetitive
  String getReminderMessage() {
    final rand = Random();
    final now = DateTime.now();

    // Get the user's time for more personalized messages (e.g. "before 8 PM" instead of "soon")
    final nextHour = (now.hour + 1) % 24;
    final displayHour = nextHour > 12
        ? nextHour - 12
        : (nextHour == 0 ? 12 : nextHour);
    final amPm = nextHour >= 12 ? "PM" : "AM";

    final dynamicTime = "before $displayHour $amPm";

    final tasks = [
      "Go for a walk",
      "Drink water",
      "Log a snack",
      "Stay hydrated",
      "Go to the gym",
      "Train chest",
      "Study for my exam",
      "Finish a task",
      "Meditate for a few minutes",
      "Go outside for some fresh air",
      "Walk the dog",
      "Share Level Up! with my friends",
      "Use the Explore tab to get some steps in",
    ];

    final timeOptions = [
      dynamicTime,
      "before midnight",
      "today",
      "tomorrow",
      "soon",
      "now",
      "",
    ];

    final extras = [
      "to stay on track",
      "like a pro",
      "before it gets too late",
      "",
    ];

    final punctuation = [
      ".",
      "!",
      ". 🙂",
      "! 💪",
      "! ⚡️",
      ". ✅",
      "! 🚀",
      ". ✨",
      "! 💯",
      ". 🎯",
      "! 🔥",
      " 🌊",
      " 🙌",
      "",
    ];

    // randomly construct the message
    final task = tasks[rand.nextInt(tasks.length)];
    final time = timeOptions[rand.nextInt(timeOptions.length)];
    final extra = extras[rand.nextInt(extras.length)];
    final punct = punctuation[rand.nextInt(punctuation.length)];

    final parts = [task];
    if (time.isNotEmpty) parts.add(time);
    if (extra.isNotEmpty) parts.add(extra);

    return parts.join(" ") + punct;
  }

  // Method that deletes a reminder from the Supabase Postgres db
  Future<void> _deleteReminder(ReminderData reminder) async {
    if (isGuest) {
      Guest.block(context);
      return;
    } // For guest users
    final confirmed = await showFrostedAlertDialog<bool>(
      context: context,
      title: "Delete reminder?",
      content: RichText(
        text: TextSpan(
          style: GoogleFonts.manrope(color: Colors.white70),
          children: [
            const TextSpan(text: "You're deleting the reminder:\n\n"),
            TextSpan(
              text: reminder.message,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
    if (confirmed != true) return;

    try {
      final response = await authenticatedPost(
        'delete_reminder',
        body: {'reminder_id': reminder.id},
      );

      if (response.statusCode != 200) {
        _showSnackbar("Failed to delete reminder", isError: true);
        return;
      }

      final updatedReminders = reminders
          .where((r) => r.id != reminder.id)
          .toList();

      if (mounted) {
        setState(() => reminders = updatedReminders);
        _showSnackbar("Reminder deleted successfully!");
      }
      currentUserData?.reminders = List.from(updatedReminders);
    } catch (e) {
      if (kDebugMode) debugPrint("Error deleting reminder: $e");
      _showSnackbar("Failed to delete reminder", isError: true);
    }
  }

  Future<void> pickDateTime(
    BuildContext context,
    DateTime dateTime,
    Function(DateTime) onPicked,
  ) async {
    await showFrostedDialog(
      context: context,
      child: SizedBox(
        height: Responsive.height(context, 300),
        width: Responsive.width(context, 400),
        child: Column(
          children: [
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime: dateTime,
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
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    _setReminder();
                  },
                  child: const Text(
                    "Set Reminder",
                    style: TextStyle(color: Colors.white),
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
                Text(message), // Message text
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
      Guest.block(context);
      return;
    } // For guest users
    if (isLoading) return;

    if (remindersController.text.isEmpty) {
      _showSnackbar("All fields must be filled.", isError: true);
      return;
    }

    if (!_dateTimePicked) {
      _showSnackbar("A reminder time must be chosen.", isError: true);
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
      final id = DateTime.now().millisecondsSinceEpoch;

      final response = await authenticatedPost(
        'set_reminder',
        body: {
          'message': remindersController.text,
          'scheduled_at': pickedTime.toUtc().toIso8601String(),
          'notification_id': id,
        },
      );

      if (response.statusCode != 200) {
        _showSnackbar(
          "Failed to set reminder: Status code ${response.statusCode}",
          isError: true,
        );
        return;
      }

      _showSnackbar("Reminder set successfully!");
      remindersController.clear();
      setState(() => _dateTimePicked = false);
      await _loadRemindersFromServer();

      // Track future_reminder if the reminder is 1+ month out
      if (pickedTime.isAfter(DateTime.now().add(const Duration(days: 30)))) {
        trackTrivialAchievement("future_reminder");
      }
      // Track active_reminders if the user now has 5+ active reminders
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

  // Makes a single reminder card with message, time, and delete button
  Widget _buildReminderCard(ReminderData reminder) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 10)),
      child: Row(
        children: [
          // Left accent bar sitting outside the card so it's never clipped
          Container(
            width: Responsive.width(context, 4),
            height: Responsive.height(context, 70),
            decoration: BoxDecoration(
              color: appColorNotifier.value,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(Responsive.scale(context, 4)),
                bottomLeft: Radius.circular(Responsive.scale(context, 4)),
              ),
            ),
          ),
          Expanded(
            child: frostedGlassCard(
              context,
              baseRadius: 16,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 16),
                vertical: Responsive.height(context, 14),
              ),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedNotification01,
                    color: appColorNotifier.value,
                    size: Responsive.scale(context, 22),
                  ),
                  SizedBox(width: Responsive.width(context, 14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.message,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 15),
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 4)),
                        Text(
                          _formatDateTime(reminder.scheduledAt),
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 12),
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedDelete02,
                      color: Colors.redAccent,
                      size: Responsive.scale(context, 20),
                    ),
                    onPressed: () => _deleteReminder(reminder),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: darkenColor(appColorNotifier.value, 0.025),
          centerTitle: true,
          toolbarHeight: Responsive.appBarHeight(context, 100),
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: Center(
              child: Container(
                padding: EdgeInsets.all(Responsive.scale(context, 12)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lightenColor(
                    appColorNotifier.value,
                    0.1,
                  ).withAlpha(20),
                  border: Border.all(
                    color: lightenColor(
                      appColorNotifier.value,
                      0.3,
                    ).withAlpha(180),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: lightenColor(
                    appColorNotifier.value,
                    0.3,
                  ).withAlpha(180),
                  size: Responsive.font(context, 13),
                ),
              ),
            ),
          ),
          title: createTitle("Reminders", context),
          actions: [
            if (kIsWeb)
              Padding(
                padding: EdgeInsets.only(right: Responsive.width(context, 8)),
                child: GestureDetector(
                  onTap: () => showFrostedAlertDialog(
                    context: context,
                    title: "Notifications not working?",
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "All three must be enabled:",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 13),
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 8)),
                        Text(
                          "1) In-app notifications\n2) Browser notification permissions\n3) Browser notifications in your system settings",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 13),
                            color: Colors.white54,
                            height: 1.6,
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 12)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedSmartPhone01,
                              color: Colors.white38,
                              size: Responsive.scale(context, 18),
                            ),
                            SizedBox(width: Responsive.width(context, 10)),
                            Expanded(
                              child: Text(
                                "iPhone users must install Level Up! as a PWA (Add to Home Screen) for notifications to work.",
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 13),
                                  color: Colors.white54,
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
                            child: const Text(
                              "Dismiss",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: EdgeInsets.all(Responsive.scale(context, 12)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: lightenColor(
                        appColorNotifier.value,
                        0.1,
                      ).withAlpha(20),
                      border: Border.all(
                        color: lightenColor(
                          appColorNotifier.value,
                          0.3,
                        ).withAlpha(180),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      "?",
                      style: TextStyle(
                        color: lightenColor(
                          appColorNotifier.value,
                          0.3,
                        ).withAlpha(180),
                        fontSize: Responsive.font(context, 13),
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(Responsive.height(context, 3)),
            child: Container(
              height: Responsive.height(context, 3),
              color: Colors.white.withAlpha(25),
            ),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.centeredHorizontalPadding(context, 50),
                  vertical: Responsive.height(context, 24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sectionHeader("REMINDER DETAILS", context),
                    frostedGlassCard(
                      context,
                      padding: EdgeInsets.all(Responsive.scale(context, 20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Text field
                          TextField(
                            enabled: !_notifBlocked,
                            minLines: 1,
                            maxLines:
                                null, // allow the text field to expand vertically as the user types more lines
                            controller: remindersController,
                            keyboardType: TextInputType.text,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 15),
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: Padding(
                                padding: EdgeInsets.only(
                                  left: Responsive.width(context, 12),
                                  right: Responsive.width(context, 10),
                                ),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedMessage01,
                                  color: lightenColor(
                                    appColorNotifier.value,
                                    0.3,
                                  ),
                                  size: Responsive.scale(context, 18),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(),
                              hintText:
                                  "Enter a reminder message (E.g. $placeholderMessage)",
                              hintStyle: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 14),
                                color: Colors.white38,
                              ),
                              filled: true,
                              fillColor: Colors.white.withAlpha(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  Responsive.scale(context, 12),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.white.withAlpha(40),
                                  width: Responsive.scale(context, 1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  Responsive.scale(context, 12),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.white.withAlpha(40),
                                  width: Responsive.scale(context, 1),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  Responsive.scale(context, 12),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.white.withAlpha(80),
                                  width: Responsive.scale(context, 1.5),
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 16),
                                vertical: Responsive.height(context, 12),
                              ),
                            ),
                            onChanged: (value) => reminder = value,
                          ),
                          SizedBox(height: Responsive.height(context, 14)),

                          // Selected date/time display, validates message before opening picker
                          GestureDetector(
                            onTap: _notifBlocked
                                ? null
                                : () {
                                    if (remindersController.text
                                        .trim()
                                        .isEmpty) {
                                      _showSnackbar(
                                        "Enter a message first.",
                                        isError: true,
                                      );
                                      return;
                                    }
                                    pickDateTime(
                                      context,
                                      dateTime,
                                      (newDate) => setState(() {
                                        dateTime = newDate;
                                        _dateTimePicked = true;
                                      }),
                                    );
                                  },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 16),
                                vertical: Responsive.height(context, 12),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(12),
                                borderRadius: BorderRadius.circular(
                                  Responsive.scale(context, 12),
                                ),
                                border: Border.all(
                                  color: Colors.white.withAlpha(40),
                                  width: Responsive.scale(context, 1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedClock01,
                                    color: lightenColor(
                                      appColorNotifier.value,
                                      0.3,
                                    ),
                                    size: Responsive.scale(context, 18),
                                  ),
                                  SizedBox(
                                    width: Responsive.width(context, 10),
                                  ),
                                  Expanded(
                                    child: Text(
                                      !_dateTimePicked
                                          ? "Enter a reminder time"
                                          : _formatDateTime(dateTime),
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(context, 15),
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ),

                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedArrowRight01,
                                    color: Colors.white38,
                                    size: Responsive.scale(context, 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isLoading)
                            Padding(
                              padding: EdgeInsets.only(
                                top: Responsive.height(context, 16),
                              ),
                              child: Center(
                                child: SizedBox(
                                  height: Responsive.scale(context, 24),
                                  width: Responsive.scale(context, 24),
                                  child: CircularProgressIndicator(
                                    strokeWidth: Responsive.scale(context, 2),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.height(context, 28)),

                    // --- Section header ---
                    sectionHeader("UPCOMING REMINDERS", context),

                    // Reminder list or empty state
                    reminders.isEmpty
                        ? Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: Responsive.height(context, 32),
                            ),
                            child: frostedGlassCard(
                              context,
                              padding: EdgeInsets.symmetric(
                                vertical: Responsive.height(context, 32),
                                horizontal: Responsive.width(context, 20),
                              ),
                              child: Column(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedNotification02,
                                    color: Colors.white24,
                                    size: Responsive.scale(context, 48),
                                  ),
                                  SizedBox(
                                    height: Responsive.height(context, 12),
                                  ),
                                  Text(
                                    "No upcoming reminders",
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 15),
                                      color: Colors.white38,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(
                                    height: Responsive.height(context, 6),
                                  ),
                                  Text(
                                    "Type a message above and tap the time row to set one.",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 13),
                                      color: Colors.white24,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: reminders
                                .map(_buildReminderCard)
                                .toList(),
                          ),

                    SizedBox(height: Responsive.height(context, 40)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
