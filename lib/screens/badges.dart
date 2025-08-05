import 'package:flutter/material.dart';

class Badges extends StatefulWidget{
  const Badges({super.key});
  
  @override
  State<Badges> createState() => _BadgesState();
}

class _BadgesState extends State<Badges> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Badges")
      ),
      body: Center(
        child: Text("Badges tab")
      )
    );
  }
}