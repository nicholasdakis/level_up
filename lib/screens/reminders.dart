import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../globals.dart';
import 'dart:math';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Reminders extends StatefulWidget {
  const Reminders({super.key});

  @override
  State<Reminders> createState() => _RemindersState();
}

class _RemindersState extends State<Reminders> {
  // Whether a snackbar is already opened
  bool snackbarActive = false;

  // Controller for user to type in their reminder
  TextEditingController remindersController = TextEditingController();

  String? reminder = ""; // the user's stored reminder

  // Default date/time for picker
  DateTime dateTime = DateTime.now();

  // The spinner for picking date and time
  Widget buildDateTimePicker() => CupertinoDatePicker(
    initialDateTime: dateTime,
    mode: CupertinoDatePickerMode.dateAndTime,
    onDateTimeChanged: (newDate) {
      setState(() => dateTime = newDate); // update user's chosen date
    },
  );

  @override
  Widget build(BuildContext context) {
    double screenHeight = 1.sh;
    double screenWidth = 1.sw;

    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        centerTitle: true,
        toolbarHeight: screenHeight * 0.15,
        title: createTitle("Reminders", screenWidth),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input field for reminder text
            TextField(
              controller: remindersController,
              keyboardType: TextInputType.text,
              style: GoogleFonts.manrope(
                fontSize: screenWidth * 0.05,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(4, 4),
                    blurRadius: 10,
                    color: const Color.fromARGB(255, 0, 0, 0),
                  ),
                ],
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 0.25),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 0.25),
                ),
                hintText: "       Enter a reminder.",
                contentPadding: EdgeInsets.only(top: 13, left: 6),
                hintStyle: GoogleFonts.manrope(
                  fontSize: screenWidth * 0.05,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(4, 4),
                      blurRadius: 10,
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                  ],
                ),
              ),
              onChanged: (value) {
                reminder = value; // store user input
              },
            ),
            SizedBox(height: screenHeight * 0.02),
            // Button to pick reminder time
            customButton(
              "Pick Reminder Time",
              screenWidth * 0.05,
              screenHeight,
              screenWidth,
              context,
              destination: null,
              onPressed: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (_) => Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      height: 0.33 * screenHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 37, 37, 37).withAlpha(128),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Column(
                          children: [
                            Expanded(child: buildDateTimePicker()),
                            CupertinoButton(
                              child: customButton(
                                "Confirm",
                                screenWidth * 0.9,
                                screenHeight * 0.33,
                                screenWidth * 0.6,
                                context,
                                destination: null,
                                onPressed: () => Navigator.pop(context),
                              ),
                              onPressed: () {
                                Navigator.pop(context); // close spinner
                                reminder = remindersController.text;

                                // Round picked time to the minute
                                final pickedTime = DateTime(
                                  dateTime.year,
                                  dateTime.month,
                                  dateTime.day,
                                  dateTime.hour,
                                  dateTime.minute,
                                );

                                // DEBUG: show what was picked
                                debugPrint(
                                  "Picked time (rounded): $pickedTime",
                                );
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
            // Set Reminder Button
            SizedBox(
              height: screenHeight * 0.075,
              width: screenWidth * 0.9,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: Color(0xFF2A2A2A),
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.black,
                    width: screenWidth * 0.005,
                  ),
                ),
                onPressed: () async {
                  // Check if reminder text is empty
                  if (remindersController.text.isEmpty) {
                    if (snackbarActive) return;
                    snackbarActive = true;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.info, color: Colors.white),
                                SizedBox(width: 10),
                                Text("All fields must be filled."),
                              ],
                            ),
                          ),
                        )
                        .closed
                        .then((_) => snackbarActive = false);
                    return;
                  }

                  // Round picked time to the minute for this reminder
                  final pickedTime = DateTime(
                    dateTime.year,
                    dateTime.month,
                    dateTime.day,
                    dateTime.hour,
                    dateTime.minute,
                  );

                  final now = DateTime.now();

                  // If picked time is in the past, show snackbar and return
                  if (pickedTime.isBefore(now)) {
                    if (snackbarActive) return;
                    snackbarActive = true;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.error, color: Colors.white),
                                SizedBox(width: 10),
                                Text("Reminders must be in the future!"),
                              ],
                            ),
                          ),
                        )
                        .closed
                        .then((_) => snackbarActive = false);
                    return;
                  }

                  // Generate unique notification ID
                  final id =
                      (DateTime.now().millisecondsSinceEpoch % 2147483647 +
                          Random().nextInt(1000)) %
                      2147483647;

                  // DEBUG: print reminder info
                  debugPrint("=== DEBUG REMINDER INFO ===");
                  debugPrint("Reminder text: ${remindersController.text}");
                  debugPrint("Notification ID: $id");
                  debugPrint("Scheduled time (DateTime): $pickedTime");
                  debugPrint(
                    "Scheduled time (millisecondsSinceEpoch): ${pickedTime.millisecondsSinceEpoch}",
                  );
                  debugPrint("===========================");

                  // Schedule local notification
                  await flutterLocalNotificationsPlugin.zonedSchedule(
                    id,
                    "Reminder",
                    remindersController.text,
                    tz.TZDateTime.from(pickedTime, tz.local),
                    NotificationDetails(
                      android: AndroidNotificationDetails(
                        'reminder_channel',
                        'Reminders',
                        channelDescription: 'User reminders',
                        importance: Importance.max,
                        priority: Priority.high,
                      ),
                      iOS: DarwinNotificationDetails(),
                    ),
                    androidScheduleMode:
                        AndroidScheduleMode.exactAllowWhileIdle,
                    matchDateTimeComponents: DateTimeComponents.dateAndTime,
                  );

                  // Clear the input field after setting the reminder
                  remindersController.clear();
                  reminder = "";

                  // Confirmation snackbar
                  if (!snackbarActive) {
                    snackbarActive = true;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.info, color: Colors.white),
                                SizedBox(width: 10),
                                Text("Reminder successfully set!"),
                              ],
                            ),
                          ),
                        )
                        .closed
                        .then((_) => snackbarActive = false);
                  }
                },

                child: buttonText("Set Reminder", screenWidth * 0.085),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
