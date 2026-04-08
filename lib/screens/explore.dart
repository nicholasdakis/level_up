import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../globals.dart';
import '../utility/responsive.dart';
import '../utility/poi.dart';
import '../utility/poi_service.dart';

class Explore extends StatefulWidget {
  const Explore({super.key});

  @override
  State<Explore> createState() => _ExploreState();
}

// "with OSMMixinObserver" to listen for map ready events
class _ExploreState extends State<Explore> with OSMMixinObserver {
  GeoPoint? userLocation;
  bool cardIsOpen = false;
  double _cardOpacity = 0;
  List<POI> nearbyPOIs = []; // the list of POIs to display
  bool loadingPOIs = false; // true while fetching POIs
  String? poiError; // error message if fetching POIs fails
  final POIService _poiService =
      POIService(); // service for fetching and caching POIs
  POI? nearestPOI; // the closest unvisited POI within check-in range
  POI? _tappedPOI; // POI whose tooltip is currently showing on the map
  bool checkingIn = false; // whether a check-in request is in progress
  int?
  xpAwarded; // XP gained from the last check-in (shown briefly in the button)

  // Confetti controller for the check-in celebration
  late ConfettiController _confettiController;

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
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _poiService
        .cleanupOldVisits(); // remove expired visit records on screen open
    _initLocation();
  }

  @override
  void dispose() {
    _confettiController.dispose(); // clean up the confetti controller
    super.dispose();
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

    // Fetch nearby POIs
    _loadPOIs(position.latitude, position.longitude);
  }

  // Fetch POIs from the backend (or cache) and update the UI
  Future<void> _loadPOIs(double lat, double lng) async {
    setState(() {
      loadingPOIs = true; // show loading state
      poiError = null; // clear any previous error
    });

    try {
      // getNearbyPOIs checks the cache first, only hits backend if needed
      final pois = await _poiService.getNearbyPOIs(lat, lng);

      if (!mounted) return;

      setState(() {
        nearbyPOIs = pois; // update the list
        loadingPOIs = false;
      });

      // Add markers to the map for each POI
      _addPOIMarkers();

      // Check if the user is close enough to any POI to check in
      _updateNearestPOI();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        poiError = 'Could not load nearby spots';
        loadingPOIs = false;
      });
    }
  }

  Future<void> _updateNearestPOI() async {
    if (userLocation == null) return;

    final closest = await _poiService.getClosestCheckInPOI(
      nearbyPOIs,
      userLocation!.latitude,
      userLocation!.longitude,
      50, // 50 meters max check-in distance
    );

    if (!mounted) return;
    setState(() => nearestPOI = closest);
  }

  // Handle the check-in button tap
  Future<void> _handleCheckIn() async {
    if (nearestPOI == null || userLocation == null || checkingIn) return;

    setState(() => checkingIn = true); // show loading state on button

    try {
      // Send the check-in to the backend for verification and XP award
      final result = await _poiService.checkInPOI(
        nearestPOI!,
        userLocation!.latitude,
        userLocation!.longitude,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Update the local XP state so the XP bar updates
        if (result['new_level'] != null) {
          currentUserData!.level = result['new_level'];
        }
        if (result['new_exp'] != null) {
          currentUserData!.expPoints = result['new_exp'];
          expNotifier.value = result['new_exp']; // trigger XP bar rebuild
        }

        setState(() {
          xpAwarded = result['xp_gained']; // show XP in the button briefly
          checkingIn = false;
        });

        _confettiController.play(); // confetti celebration

        // After 2 seconds, clear the XP display and refresh nearest POI
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        setState(() => xpAwarded = null);

        // Re-check nearest POI since this one is now visited
        _updateNearestPOI();
      } else {
        // Check-in failed (cooldown or too far)
        setState(() => checkingIn = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Check-in failed'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => checkingIn = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not check in. Try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Place markers on the map for each POI
  Future<void> _addPOIMarkers() async {
    for (final poi in nearbyPOIs) {
      try {
        await mapController.addMarker(
          GeoPoint(latitude: poi.lat, longitude: poi.lng),
          markerIcon: MarkerIcon(
            icon: Icon(
              _iconForCategory(
                poi.category,
              ), // picks an icon based on the POI type
              color: darkenColor(Colors.blueAccent, 0.2).withAlpha(150),
              size: Responsive.width(context, 35),
            ),
          ),
        );
      } catch (_) {
        // skip markers that fail to add (e.g. duplicate positions)
      }
    }
  }

  // Method that returns an icon based on the POI category
  IconData _iconForCategory(String category) {
    switch (category) {
      case 'restaurant':
      case 'fast_food':
      case 'cafe':
      case 'bar':
      case 'pub':
        return Icons.restaurant;
      case 'fitness_centre':
      case 'sports_centre':
      case 'gym':
        return Icons.fitness_center;
      case 'park':
      case 'garden':
      case 'playground':
        return Icons.park;
      case 'supermarket':
      case 'convenience':
      case 'bakery':
        return Icons.shopping_cart;
      case 'pharmacy':
      case 'hospital':
      case 'clinic':
      case 'doctors':
        return Icons.local_hospital;
      case 'school':
      case 'university':
      case 'college':
      case 'library':
        return Icons.school;
      case 'hotel':
      case 'hostel':
      case 'guest_house':
        return Icons.hotel;
      case 'museum':
      case 'gallery':
      case 'theatre':
      case 'cinema':
        return Icons.museum;
      default:
        return Icons.place; // generic pin for everything else
    }
  }

  // called automatically by map controller when the map is fully initialized
  @override
  Future<void> mapIsReady(bool isReady) async {
    if (isReady && userLocation != null) {
      await mapController.moveTo(userLocation!);
      _addPOIMarkers(); // add any markers that loaded before the map was ready
    }
  }

  // Build a single POI row in the card
  Widget _poiTile(POI poi) {
    return FutureBuilder<bool>(
      future: _poiService.isVisitedRecently(
        poi.name,
      ), // check if already visited today
      builder: (context, snapshot) {
        final visited =
            snapshot.data ?? false; // default to not visited while loading

        return Padding(
          padding: EdgeInsets.symmetric(
            vertical: Responsive.height(context, 4),
          ),
          child: Row(
            children: [
              // Category icon
              Icon(
                _iconForCategory(poi.category),
                color: visited
                    ? Colors.white38
                    : Colors.white, // dim if already visited
                size: Responsive.width(context, 20),
              ),
              SizedBox(width: Responsive.width(context, 8)),
              // POI name and category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poi.name,
                      style: GoogleFonts.manrope(
                        color: visited ? Colors.white38 : Colors.white,
                        fontSize: Responsive.width(context, 16),
                      ),
                      softWrap: true, // long names wrap onto the next line
                    ),
                    // Remove the _ from POIs (e.g. fast_food becomes fast food), split them, capitalize the first word, then merge back together
                    Text(
                      poi.displayCategory, // capitalize the first letter then concatinate it with the rest of the string
                    ),
                  ],
                ),
              ),
              // Visit status indicator
              if (visited)
                Icon(
                  Icons.check_circle,
                  color: Colors.green.withAlpha(150),
                  size: Responsive.width(context, 20),
                )
              else
                Icon(
                  Icons.circle_outlined,
                  color: Colors.white38,
                  size: Responsive.width(context, 20),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double backButtonMobileOffset = cardIsOpen
        ? 300
        : 0; // offset to prevent card from covering back button on mobile devices

    return Scaffold(
      body: Stack(
        children: [
          // THE MAP
          OSMFlutter(
            controller: mapController,
            onGeoPointClicked: (geoPoint) {
              for (final poi in nearbyPOIs) {
                if (poi.lat == geoPoint.latitude &&
                    poi.lng == geoPoint.longitude) {
                  setState(() {
                    _tappedPOI = poi;
                    _cardOpacity = 1; // fade in
                  });

                  final tapped = poi;
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted && _tappedPOI == tapped) {
                      setState(() => _cardOpacity = 0); // fade out
                    }
                  });
                  return;
                }
              }
            },
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
                    size: Responsive.width(context, 35),
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
                    130 + backButtonMobileOffset,
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
                                        height: Responsive.height(context, 10),
                                      ),
                                      // Show loading spinner while fetching
                                      if (loadingPOIs)
                                        Padding(
                                          padding: EdgeInsets.all(
                                            Responsive.width(context, 20),
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      // Show error message if fetching failed
                                      else if (poiError != null)
                                        Padding(
                                          padding: EdgeInsets.all(
                                            Responsive.width(context, 10),
                                          ),
                                          child: Text(
                                            poiError!,
                                            style: GoogleFonts.manrope(
                                              color: Colors.redAccent,
                                              fontSize: Responsive.width(
                                                context,
                                                14,
                                              ),
                                            ),
                                          ),
                                        )
                                      // Show message if no POIs found
                                      else if (nearbyPOIs.isEmpty)
                                        Padding(
                                          padding: EdgeInsets.all(
                                            Responsive.width(context, 10),
                                          ),
                                          child: Text(
                                            "No spots found nearby",
                                            style: GoogleFonts.manrope(
                                              color: Colors.white70,
                                              fontSize: Responsive.width(
                                                context,
                                                14,
                                              ),
                                            ),
                                          ),
                                        )
                                      // Show the list of POIs in a scrollable container
                                      else
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxHeight: Responsive.height(
                                              context,
                                              300,
                                            ), // cap height so it doesn't fill the screen
                                          ),
                                          child: ListView.builder(
                                            shrinkWrap:
                                                true, // only take as much space as needed
                                            padding: EdgeInsets.zero,
                                            itemCount: nearbyPOIs.length,
                                            itemBuilder: (context, index) {
                                              return _poiTile(
                                                nearbyPOIs[index],
                                              );
                                            },
                                          ),
                                        ),
                                    ] else
                                      SizedBox(
                                        height: Responsive.height(context, 30),
                                        child: Center(
                                          child: Text(
                                            loadingPOIs
                                                ? "Loading spots..."
                                                : "Tap to view spots",
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

          // CHECK-IN BUTTON (only visible when near an unvisited POI)
          if (nearestPOI != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: Responsive.height(context, 40),
                ),
                child: PointerInterceptor(
                  child: GestureDetector(
                    onTap: checkingIn
                        ? null
                        : _handleCheckIn, // disable while checking in
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 24),
                        vertical: Responsive.height(context, 14),
                      ),
                      decoration: BoxDecoration(
                        // Green when XP was just awarded, blue otherwise
                        color: xpAwarded != null
                            ? Colors.green.withAlpha(220)
                            : Colors.blue.withAlpha(220),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(100),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min, // only as wide as its content
                        children: [
                          // Show a spinner while checking in, a check icon after success, or location icon normally
                          if (checkingIn)
                            SizedBox(
                              width: Responsive.width(context, 20),
                              height: Responsive.width(context, 20),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          else
                            Icon(
                              xpAwarded != null
                                  ? Icons.check_circle
                                  : Icons.location_on,
                              color: Colors.white,
                              size: Responsive.width(context, 22),
                            ),
                          SizedBox(width: Responsive.width(context, 8)),
                          // Show "+" XP after success, or the POI name normally
                          Text(
                            xpAwarded != null
                                ? "+$xpAwarded XP!"
                                : "Check in: ${nearestPOI!.name}",
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: Responsive.width(context, 16),
                              fontWeight: FontWeight.bold,
                            ),
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // POI TOOLTIP (shown when the user taps a marker)
          if (_tappedPOI != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                opacity: _cardOpacity,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: Responsive.height(
                      context,
                      nearestPOI != null ? 100 : 40,
                    ),
                  ),
                  child: PointerInterceptor(
                    child: GestureDetector(
                      onTap: () => setState(() => _cardOpacity = 0),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 16),
                          vertical: Responsive.height(context, 10),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(210),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(80),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _iconForCategory(_tappedPOI!.category),
                              color: Colors.white,
                              size: Responsive.width(context, 22),
                            ),
                            SizedBox(width: Responsive.width(context, 8)),
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _tappedPOI!.name,
                                    style: GoogleFonts.manrope(
                                      color: Colors.white,
                                      fontSize: Responsive.width(context, 16),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    softWrap: true,
                                  ),
                                  Text(
                                    _tappedPOI!.displayCategory,
                                    style: GoogleFonts.manrope(
                                      color: Colors.white70,
                                      fontSize: Responsive.width(context, 13),
                                    ),
                                  ),
                                ],
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

          // CONFETTI (centered at the top, rains down over the whole screen)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality:
                  BlastDirectionality.explosive, // all directions
              emissionFrequency: 0.03, // how often new particles spawn
              numberOfParticles: 30, // how many per blast
              gravity: 0.2, // how fast they fall
              shouldLoop: false, // play once per check-in
              maxBlastForce: 25, // max speed
              minBlastForce: 10, // min speed
              particleDrag: 0.05, // air resistance
              colors: [
                Colors.yellow,
                Colors.green,
                Colors.blue,
                Colors.purple,
                Colors.orange,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
