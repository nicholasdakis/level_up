import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../globals.dart';
import '../user/reminder_data.dart';

class Reminders extends StatefulWidget {
  const Reminders({super.key});

  @override
  State<Reminders> createState() => _RemindersState();
}

class _RemindersState extends State<Reminders> {
  bool snackbarActive = false;
  bool isLoading = false; // track the loading state for UI feedback
  final TextEditingController remindersController =
      TextEditingController(); // Input text for reminder message
  String reminder = ""; // Stores the current reminder text
  DateTime dateTime =
      DateTime.now(); // Stores the selected date and time for reminder

  List<ReminderData> reminders =
      []; // Local list to store reminders for UI display

  @override
  void initState() {
    super.initState();
    _loadReminders(); // Load reminders when the widget initializes
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
          reminderTime = DateTime.parse(data['dateTime']);
        } catch (_) {
          continue; // skip invalid date strings
        }

        final notificationId = data['notificationId'] ?? 0;

        final reminderData = ReminderData(
          message: data['message'] ?? '',
          dateTime: reminderTime,
          notificationId: notificationId,
        );

        // Reminders that have passed should be removed and not appear in the Table
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
          reminders = loadedReminders; // update the table
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

  // Method that deletes a reminder from Firestore and cancels the notification
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

      // Cancel the scheduled notification
      await flutterLocalNotificationsPlugin.cancel(reminder.notificationId);

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

  // Date/time picker (Apple-style)
  Widget buildDateTimePicker() => CupertinoDatePicker(
    initialDateTime: dateTime, // Start with current selected time
    mode: CupertinoDatePickerMode.dateAndTime,
    onDateTimeChanged: (newDate) =>
        setState(() => dateTime = newDate), // Update state on change
  );

  // Snackbar helper method
  void _showSnackbar(String message, {bool isError = false}) {
    if (snackbarActive) return; // Prevent multiple snackbars
    snackbarActive = true; // Mark as active

    // Display snackbar with message
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info, color: Colors.white), // Info icon
                SizedBox(width: 10), // Spacing
                Text(message), // Message text
              ],
            ),
          ),
        )
        .closed
        .then((_) => snackbarActive = false);
  }

  // Method that creates and schedules a new reminder
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
      debugPrint("Generating notification ID...");
      final id = Random().nextInt(2147483647);
      debugPrint("ID generated: $id");

      // Schedule the notification
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        "Reminder",
        remindersController.text,
        tz.TZDateTime.from(pickedTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel',
            'Reminders',
            channelDescription: 'User reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );

      // Update to Firestore
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('reminders')
            .add({
              'message': remindersController.text,
              'dateTime': pickedTime.toIso8601String(),
              'notificationId': id,
            });
      }
      // Confirmation snackbar
      _showSnackbar("Reminder set successfully!");
      // Catch any potential errors in setting the reminder
    } catch (e) {
      debugPrint("Error in _setReminder: $e");
      _showSnackbar("Failed to set reminder: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = 1.sh; // Screen height
    double screenWidth = 1.sw; // Screen width

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        centerTitle: true,
        toolbarHeight: screenHeight * 0.15,
        title: createTitle("Reminders", screenWidth),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            // Scrollable content
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 50,
              ), // Horizontal padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reminder text input field
                  TextField(
                    controller: remindersController,
                    keyboardType: TextInputType.text,
                    style: GoogleFonts.manrope(
                      // Custom font
                      fontSize: screenWidth * 0.05,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          // Text shadow
                          offset: Offset(4, 4),
                          blurRadius: 10,
                          color: Colors.black,
                        ),
                      ],
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: const UnderlineInputBorder(
                        // Enabled state border
                        borderSide: BorderSide(color: Colors.grey, width: 0.25),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        // Focused state border
                        borderSide: BorderSide(color: Colors.grey, width: 0.25),
                      ),
                      hintText: "Enter a reminder.",
                      contentPadding: const EdgeInsets.only(top: 13, left: 6),
                      hintStyle: GoogleFonts.manrope(
                        fontSize: screenWidth * 0.05,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            offset: Offset(4, 4),
                            blurRadius: 10,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                    onChanged: (value) =>
                        reminder = value, // Update on text change
                  ),
                  SizedBox(height: screenHeight * 0.02),

                  // Date/time picker button
                  customButton(
                    "Pick Reminder Time",
                    screenWidth * 0.05,
                    screenHeight,
                    screenWidth,
                    context,
                    destination: null,
                    onPressed: () {
                      // Show date/time picker modal
                      showCupertinoModalPopup(
                        context: context,
                        builder: (_) => Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            height: 0.33 * screenHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(128, 37, 37, 37),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Column(
                                children: [
                                  Expanded(child: buildDateTimePicker()),
                                  CupertinoButton(
                                    child: customButton(
                                      // Confirm button
                                      "Confirm",
                                      screenWidth * 0.9,
                                      screenHeight * 0.33,
                                      screenWidth * 0.6,
                                      context,
                                      destination: null,
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context); // Close picker
                                      reminder = remindersController
                                          .text; // Sync the text
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  // Set reminder button
                  SizedBox(
                    height: screenHeight * 0.075,
                    width: screenWidth * 0.9,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        backgroundColor: const Color(0xFF2A2A2A),
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.black,
                          width: screenWidth * 0.005,
                        ),
                      ),
                      onPressed: isLoading
                          ? null
                          : _setReminder, // Disable when loading
                      child: isLoading
                          ? const SizedBox(
                              // Loading indicator
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : buttonText(
                              "Set Reminder",
                              screenWidth * 0.085,
                            ), // Button text
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02), // Spacing
                  // REMINDERS TABLE WITH DELETE OPTION
                  Center(
                    child: reminders.isEmpty
                        // Case 1: No set reminders
                        ? Padding(
                            // Empty state
                            padding: EdgeInsets.only(top: screenHeight * 0.1),
                            child: Text(
                              "Upcoming reminders will appear here...",
                              style: TextStyle(
                                color: Colors.white54, // Semi-transparent text
                                fontSize: screenWidth * 0.04, // Responsive size
                              ),
                            ),
                          )
                        // Case 2: There are reminders to show
                        : DataTable(
                            // Data table for reminders
                            columns: [
                              DataColumn(
                                label: Center(
                                  child: textWithFont(
                                    "Message",
                                    screenWidth,
                                    0.04,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Center(
                                  child: textWithFont(
                                    "Date",
                                    screenWidth,
                                    0.04,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Center(
                                  child: textWithFont(
                                    "Delete",
                                    screenWidth,
                                    0.04,
                                  ),
                                ),
                              ),
                            ],
                            rows: reminders.map((reminder) {
                              return DataRow(
                                // Row for each reminder
                                cells: [
                                  DataCell(
                                    // Message cell
                                    Center(
                                      child: textWithFont(
                                        reminder.message, // Reminder text
                                        1.sw,
                                        0.02,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    // Date cell
                                    Center(
                                      child: textWithFont(
                                        "${reminder.dateTime.month}/${reminder.dateTime.day} ${reminder.dateTime.hour}:${reminder.dateTime.minute.toString().padLeft(2, '0')}", // Formatted date
                                        1.sw,
                                        0.02,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    // Delete cell
                                    Center(
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        // Delete row is clickable
                                        onPressed: () =>
                                            _deleteReminder(reminder),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
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
    );
  }
}
