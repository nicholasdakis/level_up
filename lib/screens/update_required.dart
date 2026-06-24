import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../globals.dart';
import '../home_screen.dart';

class UpdateRequiredScreen extends StatefulWidget {
  const UpdateRequiredScreen({super.key});

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await showForceUpdateDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Skeletonizer(
        enabled: true,
        child: const HomeScreen(),
      ),
    );
  }
}
