import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../globals.dart';
import '../utility/responsive.dart';

class Explore extends StatefulWidget {
  const Explore({super.key});

  @override
  State<Explore> createState() => _ExploreState();
}

// "with OSMMixinObserver" to listen for map ready events
class _ExploreState extends State<Explore> with OSMMixinObserver {
  GeoPoint? userLocation;
  bool cardIsOpen = false;

  Widget spotText(String spotName) {
    return Text(
      spotName,
      style: GoogleFonts.manrope(
        color: Colors.white,
        fontSize: Responsive.width(context, 18),
      ),
    );
  }

  // Track user location
  late final MapController mapController = MapController.withUserPosition(
    trackUserLocation: const UserTrackingOption(
      enableTracking: true, // follows user automatically
      unFollowUser: false,
    ),
  );

  @override
  void initState() {
    super.initState();
    mapController.addObserver(this); // listen to map events
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
      userLocation = GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    });

    // move map to user location and add a marker
    if (userLocation != null) {
      await mapController.moveTo(userLocation!); // move camera
    }
  }

  // called automatically by map controller
  @override
  Future<void> mapIsReady(bool isReady) async {
    if (isReady && userLocation != null) {
      await mapController.moveTo(userLocation!);
    }
  }

  @override
  Widget build(BuildContext context) {
    double backButtonOffset = cardIsOpen
        ? 150
        : 0; // offset to prevent card from covering back button on mobile devices

    return Scaffold(
      body: Stack(
        children: [
          // THE MAP
          OSMFlutter(
            controller: mapController,
            osmOption: OSMOption(
              userTrackingOption: UserTrackingOption(
                enableTracking: true,
                unFollowUser: false,
              ),
              zoomOption: ZoomOption(
                initZoom: 15,
                minZoomLevel: 2,
                maxZoomLevel: 19,
              ),
              userLocationMarker: UserLocationMaker(
                personMarker: MarkerIcon(
                  icon: Icon(
                    // User marker
                    Icons.location_pin,
                    color: darkenColor(Colors.red, 0.1),
                    size: Responsive.width(context, 45),
                  ),
                ),
                directionArrowMarker: MarkerIcon(
                  icon: Icon(
                    Icons.double_arrow,
                    size: Responsive.width(context, 50),
                  ),
                ),
              ),
              roadConfiguration: RoadOption(roadColor: Colors.yellowAccent),
            ),
          ),

          // Loading screen while getting user's coordinates
          if (userLocation == null)
            Container(
              color: Colors.black54,
              child: Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: Responsive.height(context, 10)),
                    Text(
                      "Retrieving location...",
                      style: TextStyle(
                        fontSize: Responsive.width(context, 35),
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Back button
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300), // animation speed
            curve: Curves.easeInOut, // smooth curve
            top: Responsive.isDesktop(context)
                ? Responsive.height(context, 10)
                : Responsive.height(
                    context,
                    130 + backButtonOffset,
                  ), // prevent back button from being covered on mobile
            left: Responsive.width(context, 10),
            child: PointerInterceptor(
              // PointerInterceptor so the back button can be clicked
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.all(Responsive.width(context, 20)),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(200),
                    shape: BoxShape.circle,
                  ),
                  child: Tooltip(
                    message: "Back",
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),

          // THE "NEARBY EXPERIENCE SPOTS" CARD
          Padding(
            padding: EdgeInsets.all(Responsive.padding(context, 8.0)),
            child: Align(
              alignment: Alignment.topCenter, // center the widget
              child: PointerInterceptor(
                // PointerInterceptor so the widget can be clicked
                child: GestureDetector(
                  onTap: () {
                    setState(
                      () => cardIsOpen = !cardIsOpen,
                    ); // toggle open/close
                  },
                  child: ConstrainedBox(
                    // keeps width consistent without taking full screen
                    constraints: BoxConstraints(
                      maxWidth: Responsive.width(context, 400), // widget width
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 313),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(200),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(Responsive.width(context, 10)),
                        child: Column(
                          mainAxisSize: MainAxisSize
                              .min, // So widget doesn't take the height of the whole screen
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Nearby Experience Spots",
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.width(context, 25),
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(
                                    width: Responsive.width(context, 10),
                                  ),
                                  Icon(
                                    cardIsOpen
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),

                            ClipRect(
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 313),
                                curve: Curves.easeInOut,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Spread operator to add the text into the Column with one if statement
                                    if (cardIsOpen) ...[
                                      SizedBox(
                                        height: Responsive.height(context, 20),
                                      ),
                                      spotText("Spot 1"),
                                      spotText("Spot 2"),
                                      spotText("Spot 3"),
                                      spotText("Spot 4"),
                                      spotText("Spot 5"),
                                    ] else
                                      SizedBox(
                                        height: Responsive.height(context, 30),
                                        child: Center(
                                          child: Text(
                                            "Tap to view spots",
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: Responsive.width(
                                                context,
                                                15,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
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
            ),
          ),
        ],
      ),
    );
  }
}
