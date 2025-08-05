import 'package:flutter/material.dart';

class FoodLogging extends StatefulWidget{
  const FoodLogging({super.key});
  
  @override
  State<FoodLogging> createState() => _FoodLoggingState();
}

class _FoodLoggingState extends State<FoodLogging> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Food Logging")
      ),
      body: Center(
        child: Text("Food logging tab")
      )
    );
  }
}