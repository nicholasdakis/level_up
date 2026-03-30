import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../globals.dart';
import '../user/reminder_data.dart';
import '../utility/responsive.dart';
import 'package:flutter/foundation.dart';

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
  final TextEditingController remindersController =
      TextEditingController(); // Input text for reminder message
  String reminder = "";
  DateTime dateTime =
      DateTime.now(); // Stores the selected date and time for reminder

  List<ReminderData> reminders =
      []; // Local list to store reminders for UI display

  @override
  void initState() {
    super.initState();
    _loadReminders(); // Load reminders when the widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!currentUserData!.notificationsEnabled) {
        _showNotificationsDisabledDialog(); // prompt user to enable notifications
      }
    });
  }

  void _showNotificationsDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Notifications Disabled"),
        content: Text("Enable notifications to receive reminders."),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Dismiss"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await userManager.updateNotificationsEnabled(true);
              // If no FCM token, the browser is blocking notifications
              if (mounted && (currentUserData?.fcmTokens.isEmpty == true)) {
                showBrowserBlockedDialog(context);
              }
            },
            child: Text("Enable"),
          ),
        ],
      ),
    );
  }

  // Loads reminders from Firestore and removes past ones
  Future<void> _loadReminders() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('reminders')
          .get();

      // If no documents, clear reminders and exit early
      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            reminders = [];
          });
        }
        currentUserData?.reminders = [];
        return; // no reminders to process
      }

      final now = DateTime.now();
      final loadedReminders = <ReminderData>[];
      final remindersToDelete = <ReminderData>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        // Defensive parsing with null check & try-catch
        DateTime? reminderTime;
        try {
          if (data['dateTime'] == null) continue; // skip null dates
          reminderTime = DateTime.parse(data['dateTime']).toLocal();
        } catch (_) {
          continue; // skip invalid date strings
        }

        final notificationId = data['notificationId'] ?? 0;

        final reminderData = ReminderData(
          message: data['message'] ?? '',
          dateTime: reminderTime,
          notificationId: notificationId,
        );

        // Reminders that have passed should be removed and not appear in the list
        if (reminderTime.isAfter(now)) {
          loadedReminders.add(reminderData);
        } else {
          remindersToDelete.add(reminderData);
        }
      }

      // Delete past reminders if any
      for (final reminder in remindersToDelete) {
        await _deleteReminder(reminder);
      }

      // Sort by date in ascending order
      loadedReminders.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      if (mounted) {
        setState(() {
          reminders = loadedReminders; // update the list
        });
      }

      currentUserData?.reminders = List.from(loadedReminders);
    } catch (e) {
      debugPrint("Error loading reminders: $e");
      if (mounted) {
        // reset reminders in the case of an error being caught
        setState(() {
          reminders = [];
        });
      }
      currentUserData?.reminders = [];
    }
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
      "Log breakfast",
      "Log lunch",
      "Log dinner",
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
      "now"
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

  // Method that deletes a reminder from Firestore
  Future<void> _deleteReminder(ReminderData reminder) async {
    final uid = FirebaseAuth.instance.currentUser?.uid; // Get current user ID
    if (uid == null) return; // Exit if no user logged in

    try {
      // Find the reminder documents with matching notification ID
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('reminders')
          .where('notificationId', isEqualTo: reminder.notificationId)
          .get();

      // Delete all matching documents from Firestore
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete(); // Remove from database
      }

      // Update local state by removing the deleted reminder
      final updatedReminders = reminders
          .where((r) => r.notificationId != reminder.notificationId)
          .toList();

      // Refresh the UI
      if (mounted) {
        setState(() {
          reminders = updatedReminders; // Update local list
        });
      }

      // Update global user data
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
    if (kIsWeb && Responsive.isDesktop(context)) {
      // Desktop uses a Material pickers
      final pickedDate = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime(2100),
        initialEntryMode: DatePickerEntryMode
            .calendarOnly, // prevent users from editing text directly
      );

      if (pickedDate != null) {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(dateTime),
          initialEntryMode: TimePickerEntryMode
              .dialOnly, // prevent users from editing text directly
          builder: (context, child) => Theme(
            // Give the picker a custom theme that matches the user's app color
            data: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.dark(
                primary: appColorNotifier.value,
                onPrimary: Colors.white,
                secondary: appColorNotifier.value,
                onSecondary: Colors.white,
                tertiary: appColorNotifier.value,
                onTertiary: Colors.white,
                surface: darkenColor(appColorNotifier.value, 0.1).withAlpha(75),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          ),
        );

        if (pickedTime != null) {
          onPicked(
            DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            ),
          );
        }
      }
    } else {
      // Mobile or mobile web shows the Cupertino picker (feels natural on mobile but not on desktop)
      showCupertinoModalPopup(
        context: context,
        builder: (_) => SizedBox(
          height: Responsive.height(context, 350),
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(128, 37, 37, 37),
              borderRadius: BorderRadius.circular(
                Responsive.height(context, 30),
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: CupertinoDatePicker(
                    initialDateTime: dateTime,
                    mode: CupertinoDatePickerMode.dateAndTime,
                    use24hFormat: true,
                    onDateTimeChanged: (newDate) => onPicked(newDate),
                  ),
                ),
                CupertinoButton(
                  child: Text("Confirm"),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }
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

  // Method that saves a new reminder to Firestore
  Future<void> _setReminder() async {
    if (isLoading) return;
    // validation check: reminder message cannot be empty
    if (remindersController.text.isEmpty) {
      _showSnackbar("All fields must be filled.", isError: true);
      return;
    }

    final pickedTime = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
    );

    // validation check: reminder message can't be a past date
    final now = DateTime.now();
    if (pickedTime.isBefore(now)) {
      _showSnackbar("Reminders must be in the future!", isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      debugPrint("Generating reminder ID...");
      final id = Random().nextInt(2147483647);
      debugPrint("ID generated: $id");

      // Save reminder to Firestore
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('reminders')
            .add({
              'message': remindersController.text,
              'dateTime': pickedTime.toUtc().toIso8601String(),
              'notificationId': id,
            });
      }
      // Confirmation snackbar
      _showSnackbar("Reminder set successfully!");
      remindersController.clear();
      await _loadReminders(); // Show the new reminder in the list upon successful save
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Responsive.scale(context, 16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(
                Responsive.scale(context, 16),
              ),
              border: Border.all(
                color: Colors.white.withAlpha(30),
                width: Responsive.width(context, 1),
              ),
            ),
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
                        _formatDateTime(reminder.dateTime),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Colors.white.withAlpha(18);
    final cardBorder = Border.all(
      color: Colors.white.withAlpha(30),
      width: Responsive.width(context, 1),
    );
    final cardRadius = BorderRadius.circular(Responsive.scale(context, 20));

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: darkenColor(appColorNotifier.value, 0.025),
          centerTitle: true,
          toolbarHeight: Responsive.height(context, 100),
          title: createTitle("Reminders", context),
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
                    ClipRRect(
                      borderRadius: cardRadius,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 12,
                          sigmaY: 12,
                        ), // blur to give a glass effect
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: cardRadius,
                            border: cardBorder,
                          ),
                          padding: EdgeInsets.all(
                            Responsive.scale(context, 20),
                          ),
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
                                      "Set a reminder: (E.g. ${getReminderMessage()})",
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
                                  (newDate) =>
                                      setState(() => dateTime = newDate),
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
                                      Text(
                                        _formatDateTime(dateTime),
                                        style: GoogleFonts.manrope(
                                          fontSize: Responsive.font(
                                            context,
                                            14,
                                          ),
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const Spacer(),
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

                              // Set reminder button
                              isLoading
                                  ? const Center(
                                      child: SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : SizedBox(
                                      height: Responsive.height(context, 48),
                                      child: ElevatedButton(
                                        onPressed: _setReminder,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              appColorNotifier.value,
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
                                            fontSize: Responsive.font(
                                              context,
                                              15,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: Responsive.height(context, 28)),

                    // --- Section header ---
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: Responsive.height(context, 12),
                      ),
                      child: Text(
                        "UPCOMING REMINDERS",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 11),
                          color: Colors.white38,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),

                    // --- Reminder list or empty state ---
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

                                  // Temporary note about iPhone web limitations until PWA support is added
                                  SizedBox(
                                    height: Responsive.height(context, 100),
                                  ),
                                  Text(
                                    "Note: Reminders currently do not trigger notifications on iPhone web.",
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 25),
                                      color: darkenColor(
                                        appColorNotifier.value,
                                        0.1,
                                      ),
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
