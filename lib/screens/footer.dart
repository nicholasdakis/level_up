import 'package:flutter/material.dart';

Widget buildFooter(double screenHeight, double screenWidth, Widget selectedProfileImage) {
  return Container(
    height: screenHeight * 0.15,
    width: screenWidth,
    color: Color(0xFF121212),
    padding: EdgeInsets.all(25),
    child: Center(
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Outer EXP bar
              Container(
                height: screenHeight * 0.03,
                width: screenWidth * 0.7,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Inner EXP bar
              Positioned(
                // align onto the outer bar
                top: screenWidth * 0.01,
                child: Container(
                  height: screenHeight * 0.02,
                  width: screenWidth * 0.65,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 227, 210, 210),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Circle overlapping the bar with user's profile picture
              Positioned(
                // Properly align with the experience bar
                right: screenHeight * -0.07,
                top: screenHeight * -0.03,
                child: Container(
                  width: screenHeight * 0.09,
                  height: screenHeight * 0.09,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                  ),
                  child: ClipOval(child: selectedProfileImage), // the profile picture
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
