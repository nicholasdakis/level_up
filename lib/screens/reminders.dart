import 'dart:math';
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

  // Date/time picker (Apple-style)
  Widget buildDateTimePicker() => CupertinoDatePicker(
    initialDateTime: dateTime, // Start with current selected time
    mode: CupertinoDatePickerMode.dateAndTime,
    onDateTimeChanged: (newDate) =>
        setState(() => dateTime = newDate), // Update state on change
  );

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

    // Display snackbar with message
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info, color: Colors.white), // Info icon
                SizedBox(width: Responsive.width(context, 10)), // Spacing
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
      await _loadReminders(); // Show the new reminder in the table upon successful save
    } catch (e) {
      debugPrint("Error in _setReminder: $e");
      _showSnackbar("Failed to set reminder: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Body color
        // Header box
        appBar: AppBar(
          backgroundColor: darkenColor(
            appColorNotifier.value,
            0.025,
          ), // Header color
          centerTitle: true,
          toolbarHeight: Responsive.height(
            context,
            100,
          ), // for scaling responsively
          title: createTitle("Reminders", context),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              // Scrollable content
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(
                    context,
                    50,
                  ), // scaling responsively
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Reminder text input field
                    TextField(
                      controller: remindersController,
                      keyboardType: TextInputType.text,
                      style: GoogleFonts.manrope(
                        // Custom font
                        fontSize: Responsive.font(
                          context,
                          18,
                        ), // scaling responsively
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
                        enabledBorder: UnderlineInputBorder(
                          // Enabled state border
                          borderSide: BorderSide(
                            color: Colors.grey,
                            width: Responsive.width(context, 0.25), // scaling
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          // Focused state border
                          borderSide: BorderSide(
                            color: Colors.grey,
                            width: Responsive.width(context, 0.25), // scaling
                          ),
                        ),
                        hintText: "Enter a reminder.",
                        contentPadding: EdgeInsets.only(
                          top: Responsive.height(context, 10),
                          left: Responsive.width(context, 25),
                        ),
                        hintStyle: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 30),
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
                    SizedBox(height: Responsive.height(context, 20)),

                    // Date/time picker button
                    customButton(
                      "Pick Reminder Time",
                      48,
                      160,
                      750,
                      context,
                      destination: null,
                      onPressed: () {
                        pickDateTime(context, dateTime, (newDate) {
                          setState(() => dateTime = newDate);
                        });
                      },
                    ),
                    SizedBox(height: Responsive.height(context, 20)),
                    // Set reminder button
                    isLoading
                        ? Center(
                            child: SizedBox(
                              height: Responsive.height(context, 20),
                              width: Responsive.width(context, 20),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : simpleCustomButton(
                            "Set Reminder",
                            48,
                            160,
                            750,
                            context,
                            baseColor: darkenColor(
                              appColorNotifier.value,
                              0.025,
                            ), // Header color
                            onPressed: (_setReminder),
                          ),
                    SizedBox(height: Responsive.height(context, 20)), // Spacing
                    // REMINDERS TABLE WITH DELETE OPTION
                    Center(
                      child: reminders.isEmpty
                          // Case 1: No set reminders
                          ? Padding(
                              // Empty state
                              padding: EdgeInsets.only(
                                top: Responsive.height(context, 10),
                              ),
                              child: Text(
                                "Upcoming reminders will appear here...",
                                style: TextStyle(
                                  color:
                                      Colors.white54, // Semi-transparent text
                                  fontSize: Responsive.font(
                                    context,
                                    16,
                                  ), // Responsive size
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
                                      context,
                                      0.04,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Center(
                                    child: textWithFont("Date", context, 0.04),
                                  ),
                                ),
                                DataColumn(
                                  label: Center(
                                    child: textWithFont(
                                      "Delete",
                                      context,
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
                                          context,
                                          Responsive.font(context, 25),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      // Date cell
                                      Center(
                                        child: textWithFont(
                                          "${reminder.dateTime.month}/${reminder.dateTime.day} ${reminder.dateTime.hour}:${reminder.dateTime.minute.toString().padLeft(2, '0')}", // Formatted date
                                          context,
                                          Responsive.font(
                                            context,
                                            25,
                                          ), // scaled
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
                                          // Delete column cells are clickable
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
      ),
    );
  }
}
