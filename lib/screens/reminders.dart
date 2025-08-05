import 'package:flutter/material.dart';

class Reminders extends StatefulWidget{
  const Reminders({super.key});
  
  @override
  State<Reminders> createState() => _RemindersState();
}

class _RemindersState extends State<Reminders> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Reminders")
      ),
      body: Center(
        child: Text("Reminders tab")
      )
    );
  }
}