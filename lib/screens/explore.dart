import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../globals.dart';
import '../utility/responsive.dart';
import '../models/poi.dart';
import '../utility/poi/poi_icons.dart';
import '../services/poi_service.dart';
import 'dart:async';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

class Explore extends StatefulWidget {
  const Explore({super.key});

  @override
  State<Explore> createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  LatLng? userLocation;
  bool cardIsOpen = false;
  double _cardOpacity = 0; // for the fade-out
  bool loadingPOIs = false; // true while fetching POIs
  bool fillingCache = false; // true while background fill is in progress
  bool checkingIn = false; // whether a check-in request is in progress
  int?
  xpAwarded; // XP gained from the last check-in (shown briefly in the button)
  String? poiError; // error message if fetching POIs fails
  List<POI> nearbyPOIs = []; // the list of POIs to display
  POI? nearestPOI; // the closest unvisited POI within check-in range
  POI? _tappedPOI; // POI whose tooltip is currently showing on the map
  StreamSubscription<Position>?
  _positionStream; // keep track of current coordinates for POI refreshing
  late ConfettiController
  _confettiController; // confetti controller for the check-in celebration
  final POIService _poiService =
      POIService(); // service for fetching and caching POIs
  final MapController _mapController = MapController();
  double _currentZoom = 15;

  @override
  void initState() {
    super.initState();
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
    _mapController.dispose();
    _positionStream?.cancel();
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
      userLocation = LatLng(position.latitude, position.longitude);
    });

    _mapController.move(userLocation!, 15); // zoom level of 15

    // Fetch nearby POIs
    _loadPOIs(position.latitude, position.longitude);

    // start listening for position changes after permissions confirmed
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 250,
          ),
        ).listen((position) {
          if (!mounted) return;
          setState(() {
            userLocation = LatLng(position.latitude, position.longitude);
          });
          _loadPOIs(position.latitude, position.longitude);
        });
  }

  // Fetch POIs from the backend (or cache) and update the UI
  Future<void> _loadPOIs(double lat, double lng) async {
    setState(() {
      loadingPOIs = true; // show loading state
      poiError = null; // clear any previous error
    });

    try {
      // getNearbyPOIs checks the cache first and uses the backend if the cache is not filled
      final pois = await _poiService.getNearbyPOIs(
        lat,
        lng,
        onFillStart: () {
          if (!mounted) return;
          setState(() => fillingCache = true);
        },
        onSupplement: (filled) {
          if (!mounted) return;
          setState(() {
            nearbyPOIs = filled; // update the list with new POIs
            fillingCache = false;
          });
          _refreshClosestCheckinPOI(); // re-check if a new POI is now closest
        },
      );

      if (!mounted) return;

      // If the user moved far enough during the backend request, the POIs will be stale, so reject them
      // Treated as the same error as the moving too quickly backend check
      if (userLocation != null) {
        final movedMeters = _poiService.haversine(
          lat,
          lng,
          userLocation!.latitude,
          userLocation!.longitude,
        );
        if (movedMeters > 250) {
          setState(() {
            poiError = 'Moving too far too quickly. Please try again.';
            loadingPOIs = false;
            fillingCache = false;
          });
          return;
        }
      }

      setState(() {
        nearbyPOIs = pois; // update the list
        loadingPOIs = false;
        fillingCache = false;
      });

      // Check if the user is close enough to any POI to check in
      _refreshClosestCheckinPOI();
    } catch (e) {
      if (!mounted) return;
      // Match the known code from the service layer to show a tailored error message
      final isMovingTooFast = e.toString().contains(movingTooFastCode);
      setState(() {
        poiError = isMovingTooFast
            ? 'Moving too far too quickly. Please try again.'
            : 'Failed to load locations, please try again shortly.';
        loadingPOIs = false;
        fillingCache = false;
      });
    }
  }

  Future<void> _refreshClosestCheckinPOI() async {
    if (userLocation == null) return;

    final closest = await _poiService.getClosestCheckInPOI(
      nearbyPOIs,
      userLocation!.latitude,
      userLocation!.longitude,
      30, // 30 meters max check-in distance
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
        _refreshClosestCheckinPOI();
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
                POIIcons.fromCategory(poi.category),
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
                  color: Colors.green,
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

  // Build markers for all nearby POIs
  List<Marker> _buildMarkers() {
    // Map every POI into a a Marker
    return nearbyPOIs.map((poi) {
      return Marker(
        point: LatLng(poi.lat, poi.lng),
        width: Responsive.width(context, 40),
        height: Responsive.width(context, 40),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _tappedPOI = poi;
              _cardOpacity = 1; // fade in
            });

            final tapped = poi;
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && _tappedPOI == tapped) {
                setState(() => _cardOpacity = 0); // fade out
              }
            });
          },
          // Add the marker's icon
          child: Icon(
            POIIcons.fromCategory(poi.category),
            color: darkenColor(Colors.blueAccent, 0.2),
            size: Responsive.width(context, 35),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    double cardOpenMobileOffset = cardIsOpen
        ? 300
        : 0; // offset to prevent card from covering back button on mobile devices

    return Scaffold(
      body: Stack(
        children: [
          // THE MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLocation ?? const LatLng(0, 0),
              initialZoom: 15,
              minZoom: 2,
              maxZoom: 19,
              // Store the user's zoom level
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) _currentZoom = position.zoom;
              },
            ),
            children: [
              // Tile URL
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName:
                    "com.nicholasdakis.levelup (contact: n1ch0lasd4k1s@gmail.com)",
              ),

              // Attribution
              Padding(
                padding: EdgeInsets.only(
                  right: Responsive.width(context, 12),
                  bottom: Responsive.height(context, 12),
                ),
                child: RichAttributionWidget(
                  showFlutterMapAttribution: false,
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://openstreetmap.org/copyright'),
                      ),
                    ),
                  ],
                ),
              ),

              // User location layer
              CurrentLocationLayer(
                style: LocationMarkerStyle(
                  marker: DefaultLocationMarker(
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  markerSize: Size(35, 35),
                  showAccuracyCircle: false,
                  showHeadingSector: false,
                ),
              ),

              // POI markers layer
              MarkerLayer(markers: _buildMarkers()),
            ],
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

          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(Responsive.height(context, 25)),
              child: Stack(
                children: [
                  // Back button
                  AnimatedPositioned(
                    duration: const Duration(
                      milliseconds: 300,
                    ), // animation speed
                    curve: Curves.easeInOut, // smooth curve
                    top: Responsive.isDesktop(context)
                        ? Responsive.height(context, 10)
                        : Responsive.isTablet(context)
                        ? Responsive.height(context, 10)
                        : Responsive.height(
                            context,
                            130 + cardOpenMobileOffset,
                          ), // prevent back button from being covered on mobile
                    left: 0,
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: EdgeInsets.all(Responsive.width(context, 20)),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(200),
                          shape: BoxShape.circle,
                        ),
                        child: const Tooltip(
                          message: "Back",
                          child: Icon(Icons.arrow_back, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  // THE "NEARBY EXPERIENCE SPOTS" CARD
                  Align(
                    alignment: Alignment.topCenter, // center the widget
                    child: GestureDetector(
                      onTap: () {
                        setState(
                          () => cardIsOpen = !cardIsOpen,
                        ); // toggle open/close
                      },
                      child: ConstrainedBox(
                        // keeps width consistent without taking full screen
                        constraints: BoxConstraints(
                          maxWidth: Responsive.width(context, 400),
                        ),
                        child: SizedBox(
                          width: double
                              .infinity, // fill available width so edges align with buttons
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 313),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(200),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(
                                Responsive.width(context, 10),
                              ),
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
                                            fontSize: Responsive.width(
                                              context,
                                              25,
                                            ),
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
                                      duration: const Duration(
                                        milliseconds: 313,
                                      ),
                                      curve: Curves.easeInOut,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Spread operator to add the text into the Column with one if statement
                                          if (cardIsOpen) ...[
                                            SizedBox(
                                              height: Responsive.height(
                                                context,
                                                10,
                                              ),
                                            ),
                                            // Show skeleton placeholder tiles while POIs are being fetched
                                            if (loadingPOIs)
                                              Skeletonizer(
                                                enabled: true,
                                                // Subtle white shimmer to blend with the dark card background
                                                effect: ShimmerEffect(
                                                  baseColor: Colors.white
                                                      .withAlpha(30),
                                                  highlightColor: Colors.white
                                                      .withAlpha(15),
                                                  duration: const Duration(
                                                    milliseconds: 1200,
                                                  ),
                                                ),
                                                // 4 fake POI rows for Skeletonizer
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: List.generate(
                                                    4,
                                                    (_) => Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            vertical:
                                                                Responsive.height(
                                                                  context,
                                                                  4,
                                                                ),
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          // Placeholder category icon
                                                          Icon(
                                                            Icons.place,
                                                            color: Colors.white,
                                                            size:
                                                                Responsive.width(
                                                                  context,
                                                                  20,
                                                                ),
                                                          ),
                                                          SizedBox(
                                                            width:
                                                                Responsive.width(
                                                                  context,
                                                                  8,
                                                                ),
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                // Placeholder POI name
                                                                Text(
                                                                  "Loading spot name",
                                                                  style: GoogleFonts.manrope(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        Responsive.width(
                                                                          context,
                                                                          16,
                                                                        ),
                                                                  ),
                                                                ),
                                                                // Placeholder category label
                                                                Text(
                                                                  "Category",
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          // Placeholder visit status icon
                                                          Icon(
                                                            Icons
                                                                .circle_outlined,
                                                            color:
                                                                Colors.white38,
                                                            size:
                                                                Responsive.width(
                                                                  context,
                                                                  20,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            // Show error message if fetching failed and there are no POIs to fall back on
                                            else if (poiError != null &&
                                                nearbyPOIs.isEmpty)
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
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                      child: ListView.builder(
                                                        shrinkWrap:
                                                            true, // only take as much space as needed
                                                        padding:
                                                            EdgeInsets.zero,
                                                        itemCount:
                                                            nearbyPOIs.length,
                                                        itemBuilder:
                                                            (context, index) {
                                                              return _poiTile(
                                                                nearbyPOIs[index],
                                                              );
                                                            },
                                                      ),
                                                    ),
                                                    // Show a small loading indicator while the cache is being filled
                                                    if (fillingCache)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              vertical:
                                                                  Responsive.height(
                                                                    context,
                                                                    8,
                                                                  ),
                                                            ),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            SizedBox(
                                                              width:
                                                                  Responsive.width(
                                                                    context,
                                                                    14,
                                                                  ),
                                                              height:
                                                                  Responsive.width(
                                                                    context,
                                                                    14,
                                                                  ),
                                                              child:
                                                                  const CircularProgressIndicator(
                                                                    color: Colors
                                                                        .white38,
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                            ),
                                                            SizedBox(
                                                              width:
                                                                  Responsive.width(
                                                                    context,
                                                                    8,
                                                                  ),
                                                            ),
                                                            Text(
                                                              "Finding more spots...",
                                                              style: GoogleFonts.manrope(
                                                                color: Colors
                                                                    .white38,
                                                                fontSize:
                                                                    Responsive.width(
                                                                      context,
                                                                      13,
                                                                    ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                          ] else
                                            SizedBox(
                                              height: Responsive.height(
                                                context,
                                                30,
                                              ),
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
                  // CHECK-IN BUTTON (only visible when near an unvisited POI)
                  if (nearestPOI != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 40),
                        ),

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
                              mainAxisSize: MainAxisSize
                                  .min, // only as wide as its content
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
                                Flexible(
                                  child: Text(
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
                                ),
                              ],
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
                                    POIIcons.fromCategory(_tappedPOI!.category),
                                    color: Colors.white,
                                    size: Responsive.width(context, 22),
                                  ),
                                  SizedBox(width: Responsive.width(context, 8)),
                                  Flexible(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _tappedPOI!.name,
                                          style: GoogleFonts.manrope(
                                            color: Colors.white,
                                            fontSize: Responsive.width(
                                              context,
                                              16,
                                            ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          softWrap: true,
                                        ),
                                        Text(
                                          _tappedPOI!.displayCategory,
                                          style: GoogleFonts.manrope(
                                            color: Colors.white70,
                                            fontSize: Responsive.width(
                                              context,
                                              13,
                                            ),
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

                  // Re-center user button
                  if (userLocation != null)
                    // Same logic as the back button, smoothly moves the button down on mobile if the user opens the experience cards widget
                    AnimatedPositioned(
                      duration: const Duration(
                        milliseconds: 300,
                      ), // animation speed
                      curve: Curves.easeInOut, // smooth curve
                      top: Responsive.isDesktop(context)
                          ? Responsive.height(context, 10)
                          : Responsive.isTablet(context)
                          ? Responsive.height(context, 10)
                          : Responsive.height(
                              context,
                              130 + cardOpenMobileOffset,
                            ), // prevent button from being covered on mobile
                      right: 0,

                      child: GestureDetector(
                        onTap: () =>
                            _mapController.move(userLocation!, _currentZoom),
                        child: Container(
                          padding: EdgeInsets.all(
                            Responsive.width(context, 20),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(200),
                            shape: BoxShape.circle,
                          ),
                          child: Tooltip(
                            message: "Recenter",
                            child: Transform.rotate(
                              angle: 0.75,
                              child: const Icon(
                                Icons.navigation_rounded,
                                color: Colors.white,
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
            ),
          ),
        ],
      ),
    );
  }
}
