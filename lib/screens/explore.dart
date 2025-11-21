import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Explore extends StatefulWidget {
  const Explore({super.key});

  @override
  State<Explore> createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  LatLng? userLocation;
  bool cardIsOpen = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    // Check location services
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return;
    }
    // Check user permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );

    if (!mounted) return;

    setState(() {
      // update user's current position
      userLocation = LatLng(position.latitude, position.longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Screen Height and Width
    double screenHeight =
        1.sh; // Make widgets the size of the user's personal screen size
    //double screenWidth =   1.sw; // Make widgets the size of the user's personal screen size
    // Loading screen while getting user's coordinates
    if (userLocation == null) {
      return Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(child: CircularProgressIndicator()),
            SizedBox(height: 16),
            Text(
              "Retrieving location...",
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
          ],
        ),
      );
    }
    // If user's coordinates have been obtained
    return Scaffold(
      body: Stack(
        children: [
          // THE MAP
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: userLocation!,
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          // THE "NEARBY EXPERIENCE SPOTS" CARD
          Positioned(
            top: 0.075 * screenHeight,
            left: 0.025 * screenHeight,
            right: 0.025 * screenHeight,
            // Detect taps on the card
            child: GestureDetector(
              onTap: () {
                setState(() => cardIsOpen = !cardIsOpen); // toggle open/close
              },
              // Animation for the card opening / closing
              child: AnimatedSize(
                duration: Duration(milliseconds: 313),
                child: Card(
                  color: Colors.black.withAlpha(200),
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Nearby Experience Spots",
                                style: GoogleFonts.manrope(
                                  fontSize: 20.sp,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 4),
                              // Visual indicators for the card being opened or closed
                              Icon(
                                cardIsOpen
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        // Spread operator to add the text into the Column with one if statement
                        if (cardIsOpen) ...[
                          SizedBox(height: 8),
                          Text("Spot 1", style: TextStyle(color: Colors.white)),
                          Text("Spot 2", style: TextStyle(color: Colors.white)),
                          Text("Spot 3", style: TextStyle(color: Colors.white)),
                          Text("Spot 4", style: TextStyle(color: Colors.white)),
                          Text("Spot 5", style: TextStyle(color: Colors.white)),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Center(
                              child: Text(
                                "Tap to view spots",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
