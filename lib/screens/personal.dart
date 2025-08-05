import 'package:flutter/material.dart';

class Personal extends StatefulWidget{
  const Personal({super.key});
  
  @override
  State<Personal> createState() => _PersonalState();
}

class _PersonalState extends State<Personal> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Personal")
      ),
      body: Center(
        child: Text("Personal tab")
      )
    );
  }
}