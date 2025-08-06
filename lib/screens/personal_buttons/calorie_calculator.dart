import 'package:flutter/material.dart';

class CalorieCalculator extends StatefulWidget{
  const CalorieCalculator({super.key});
  
  @override
  State<CalorieCalculator> createState() => _CalorieCalculatorState();
}

class _CalorieCalculatorState extends State<CalorieCalculator> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("CalorieCalculator")
      ),
      body: Center(
        child: Text("CalorieCalculator tab")
      )
    );
  }
}