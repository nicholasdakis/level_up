import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../globals.dart';
import '../models/reminder_data.dart';
import '../utility/responsive.dart';
import '../services/fcm/notification_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentUserData?.notificationsEnabled == false) {
        _showNotificationsDisabledDialog(); // prompt user to enable notifications
      }
    });
  }

  void _showNotificationsDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("In-App Notifications Are Disabled"),
        content: Text("Enable notifications to receive reminders."),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Dismiss"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog first
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
      ),
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
      debugPrint("Failed to load reminders: $e");
    }
  }

  // Loads reminders from the Supabase Postgres db and removes past ones
  Future<List<ReminderData>> _loadReminders() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();

    final response = await http.post(
      Uri.parse('$backendBaseUrl/get_reminders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': token}),
    );

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
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();

    try {
      final response = await http.post(
        Uri.parse('$backendBaseUrl/delete_reminder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': token, 'reminder_id': reminder.id}),
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
      }
      currentUserData?.reminders = List.from(updatedReminders);
    } catch (e) {
      debugPrint("Error deleting reminder: $e");
      _showSnackbar("Failed to delete reminder", isError: true);
    }
  }

  Future<void> pickDateTime(
    BuildContext context,
    DateTime dateTime,
    Function(DateTime) onPicked,
  ) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        contentPadding: EdgeInsets.all(Responsive.padding(context, 16)),
        content: SizedBox(
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("CONFIRM"),
              ),
            ],
          ),
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
                Icon(Icons.info, color: Colors.white), // Info icon
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
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final id = DateTime.now().millisecondsSinceEpoch;

      final response = await http.post(
        Uri.parse('$backendBaseUrl/set_reminder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': token,
          'message': remindersController.text,
          'scheduled_at': pickedTime.toUtc().toIso8601String(),
          'notification_id': id,
        }),
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
      debugPrint("Error in _setReminder: $e");
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
      child: frostedGlassCard(
        context,
        baseRadius: 16,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 20),
          vertical: Responsive.height(context, 14),
        ),
        child: Row(
          children: [
            Icon(
              Icons.notifications_outlined,
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
              icon: Icon(
                Icons.delete_outline,
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
          toolbarHeight: Responsive.height(context, 100),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: createTitle("Reminders", context),
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
                  horizontal: Responsive.width(context, 50),
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
                              hintText:
                                  "Set a reminder: (E.g. $placeholderMessage)",
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
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 16),
                                vertical: Responsive.height(context, 14),
                              ),
                            ),
                            onChanged: (value) => reminder = value,
                          ),
                          SizedBox(height: Responsive.height(context, 14)),

                          // Selected date/time display
                          GestureDetector(
                            onTap: () => pickDateTime(
                              context,
                              dateTime,
                              (newDate) => setState(() {
                                dateTime = newDate;
                                _dateTimePicked = true;
                              }),
                            ),
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
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    color: appColorNotifier.value,
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

                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.white38,
                                    size: Responsive.scale(context, 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 16)),

                          // Set Reminder button
                          // if notifications are disabled, prompt the user to enable them instead
                          isLoading
                              ? Center(
                                  child: SizedBox(
                                    height: Responsive.scale(context, 24),
                                    width: Responsive.scale(context, 24),
                                    child: CircularProgressIndicator(
                                      strokeWidth: Responsive.scale(context, 2),
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  height: Responsive.height(context, 48),
                                  child: ElevatedButton(
                                    onPressed:
                                        currentUserData?.notificationsEnabled ==
                                            true
                                        ? _setReminder
                                        : () =>
                                              _showNotificationsDisabledDialog(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: appColorNotifier.value,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          Responsive.scale(context, 12),
                                        ),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      "Set Reminder",
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(context, 15),
                                        fontWeight: FontWeight.w600,
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
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: Responsive.height(context, 20),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.notifications_none,
                                    color: Colors.white24,
                                    size: Responsive.scale(context, 48),
                                  ),
                                  SizedBox(
                                    height: Responsive.height(context, 12),
                                  ),
                                  Text(
                                    "No upcoming reminders",
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 14),
                                      color: Colors.white38,
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

                    // Notes section only shows on web to inform users about browser notification requirements
                    if (kIsWeb) ...[
                      SizedBox(height: Responsive.height(context, 28)),
                      // Section header
                      sectionHeader(
                        "NOTES",
                        context,
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 10),
                          left: Responsive.width(context, 4),
                        ),
                      ),
                      frostedGlassCard(
                        context,
                        padding: EdgeInsets.all(Responsive.scale(context, 18)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Note about the 3 requirements for notifications to work on web
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.white38,
                                  size: Responsive.scale(context, 18),
                                ),
                                SizedBox(width: Responsive.width(context, 10)),
                                Expanded(
                                  child: Text(
                                    "For notifications to work, all three of the following must be enabled: in-app notifications, browser notification permissions, and browser notifications in your system settings.",
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 15),
                                      color: Colors.white54,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.height(context, 12)),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 20),
                              ),
                              child: Divider(
                                color: Colors.white.withAlpha(20),
                                height: 1,
                                thickness: 1,
                              ),
                            ),
                            SizedBox(height: Responsive.height(context, 15)),
                            // Note about iPhone PWA requirement
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.phone_iphone,
                                  color: Colors.white38,
                                  size: Responsive.scale(context, 18),
                                ),
                                SizedBox(width: Responsive.width(context, 10)),
                                Expanded(
                                  child: Text(
                                    "iPhone users must install Level Up! as a PWA (Add to Home Screen) for notifications to work.",
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 15),
                                      color: Colors.white54,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: Responsive.height(context, 40)),
                  ],
                ),
              ),
            ),

            // Loading overlay
            if (isLoading)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
