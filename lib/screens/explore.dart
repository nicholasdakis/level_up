import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../globals.dart';
import '../guest.dart';
import '../utility/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;
import '../utility/confetti.dart';
import '../models/poi.dart';
import '../utility/poi/poi_icons.dart';
import '../services/poi_service.dart';
import 'level_up_overlay.dart';
import 'dart:async';
import 'dart:ui';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:map_launcher/map_launcher.dart';

class Explore extends ConsumerStatefulWidget {
  const Explore({super.key});

  @override
  ConsumerState<Explore> createState() => _ExploreState();
}

class _ExploreState extends ConsumerState<Explore> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  LatLng? userLocation;
  bool _locationRequested =
      false; // true once the user has tapped to grant location
  bool cardIsOpen = false;
  double _cardOpacity = 0; // for the fade-out
  bool loadingPOIs = false; // true while fetching POIs
  bool _buttonPositionReady =
      false; // true once the nearby spots card has appeared, prevents the back button from animating on initial load
  bool fillingCache = false; // true while a background fill is in progress
  bool checkingIn = false; // whether a check-in request is in progress
  int _refreshVersion =
      0; // incremented on each _refreshClosestCheckinPOI call so stale results are discarded
  int?
  xpAwarded; // XP gained from the last check-in (shown briefly in the button)
  String? poiError; // error message if fetching POIs fails
  CameraConstraint _cameraConstraint = CameraConstraint.unconstrained();
  bool _usingFakePOIs =
      false; // true when fake POIs are loaded, skips real fetch on re-entry
  bool _overpassDialogShown =
      false; // prevents the dialog from stacking on repeated screen visits
  List<POI> nearbyPOIs = []; // the list of POIs to display
  POI? nearestPOI; // the closest unvisited POI within check-in range
  POI? _tappedPOI; // POI whose tooltip is currently showing on the map
  StreamSubscription<Position>?
  _positionStream; // keep track of current coordinates for POI refreshing
  final POIService _poiService =
      POIService(); // service for fetching and caching POIs
  final MapController _mapController = MapController();
  double _currentZoom = 15;

  // Restricted to the Google Play reviewer account so real users cannot fake check-ins
  static const _testUid = 'Inu2nmOe0lbwhj1zbjsk4oSf5R42';
  bool get _isTestAccount => ref.watch(userDataProvider).value?.uid == _testUid;

  // Simulated NYC spawn point (Times Square). One POI is placed exactly here so it is immediately claimable
  // User spawns ~10m from Times Square so it looks natural but is still within the 30m check-in range
  static const _simulatedLat = 40.75809;
  static const _simulatedLng = -73.98538;
  static final _simulatedPOIs = [
    POI(
      name: 'Times Square',
      lat: _simulatedLat,
      lng: _simulatedLng,
      category: 'attraction',
    ),
    POI(name: 'Bryant Park', lat: 40.7536, lng: -73.9832, category: 'park'),
    POI(
      name: 'Grand Central Terminal',
      lat: 40.7527,
      lng: -73.9772,
      category: 'landmark',
    ),
    POI(
      name: 'The Museum of Modern Art',
      lat: 40.7614,
      lng: -73.9776,
      category: 'museum',
    ),
  ];

  void _simulateLocation() {
    final loc = LatLng(_simulatedLat, _simulatedLng);
    setState(() {
      userLocation = loc;
      _locationRequested = true;
      nearbyPOIs = _simulatedPOIs;
      loadingPOIs = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(loc, 15);
      setState(() => _buttonPositionReady = true);
    });
    _refreshClosestCheckinPOI();
  }

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/explore',
      screenClass: 'Explore',
    );
    _poiService.cleanupOldVisits();
    if (isGuest) {
      // For guest users
      Guest.blockOnOpen(context);
    } else {
      _checkAndInitLocation();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _checkAndInitLocation() async {
    final permission = await Geolocator.checkPermission();
    final alreadyGranted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (alreadyGranted) {
      setState(() => _locationRequested = true);
      _initLocation();
    }
    // Otherwise the button is shown and _initLocation is called on tap
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

    // First setState: duration is zero so the button snaps instantly to its loaded position
    setState(() {
      userLocation = LatLng(position.latitude, position.longitude);
      _cameraConstraint = CameraConstraint.containCenter(
        bounds: LatLngBounds(
          LatLng(position.latitude - 0.5, position.longitude - 0.5),
          LatLng(position.latitude + 0.5, position.longitude + 0.5),
        ),
      );
    });

    // Second setState (next frame): re-enable animation so card open/close slides smoothly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _buttonPositionReady = true);
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
        ).listen(
          (position) {
            if (!mounted) return;
            final newLoc = LatLng(position.latitude, position.longitude);
            final prevLoc = userLocation;
            setState(() => userLocation = newLoc);

            // Skip if moved less than 250m (catches browsers that ignore distanceFilter)
            if (prevLoc != null &&
                _poiService.haversine(
                      prevLoc.latitude,
                      prevLoc.longitude,
                      newLoc.latitude,
                      newLoc.longitude,
                    ) <
                    250) {
              return;
            }

            _loadPOIs(newLoc.latitude, newLoc.longitude, clearExisting: true);
          },
          onError:
              (_) {}, // stream errors are non-fatal (e.g. web platform jitter)
        );
  }

  // Fetch POIs from the backend (or cache) and update the UI
  // clearExisting: true when the user has moved far enough that old POIs are stale
  Future<void> _loadPOIs(
    double lat,
    double lng, {
    bool clearExisting = false,
  }) async {
    if (loadingPOIs) return; // prevent concurrent fetches
    setState(() {
      loadingPOIs = true;
      poiError = null;
      // Don't clear fake POIs upfront; if the fetch fails they should stay visible
      if (clearExisting && !_usingFakePOIs) nearbyPOIs = [];
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

      setState(() {
        nearbyPOIs = pois; // update the list
        loadingPOIs = false;
        _usingFakePOIs = false;
        poiError = null;
      });

      // Check if the user is close enough to any POI to check in
      _refreshClosestCheckinPOI();
    } catch (e) {
      if (!mounted) return;
      // Match the known code from the service layer to show a tailored error message
      final isMovingTooFast = e.toString().contains(movingTooFastCode);
      final isOverpassDown =
          e.toString().contains('overpass_unavailable') ||
          e.toString().contains('TimeoutException');
      // If fake POIs are already showing, silently swallow the error and keep them
      if (_usingFakePOIs && (isOverpassDown || isMovingTooFast)) {
        setState(() => loadingPOIs = false);
        return;
      }
      setState(() {
        poiError = isMovingTooFast
            ? 'Moving too fast. Please try again.'
            : isOverpassDown
            ? 'Location data is unavailable right now.'
            : 'Failed to load locations. Please try again later.';
        if (!isMovingTooFast) {
          nearbyPOIs = [];
          _usingFakePOIs = false;
        }
        loadingPOIs = false;
        fillingCache = false;
        cardIsOpen = true;
      });
      if (isOverpassDown && mounted && !_overpassDialogShown) {
        _overpassDialogShown = true;
        _showOverpassFallbackDialog();
      }
    }
  }

  Future<void> _generateFakePOIs() async {
    if (userLocation == null) return;
    setState(() => loadingPOIs = true);
    try {
      final pois = await _poiService.generateFakePOIs(
        userLocation!.latitude,
        userLocation!.longitude,
      );
      if (!mounted) return;
      setState(() {
        nearbyPOIs = pois;
        poiError = null;
        loadingPOIs = false;
        cardIsOpen = true;
        _usingFakePOIs = true;
      });
      _refreshClosestCheckinPOI();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadingPOIs = false;
        poiError = 'Failed to generate spots. Please try again.';
      });
    }
  }

  void _showOverpassFallbackDialog() {
    showFrostedAlertDialog(
      context: context,
      appColor: appColor,
      title: "Couldn't Find Spots",
      content: Text(
        "Real location data is unavailable right now. Would you like to generate nearby spots instead? They work the same way.",
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 13),
          color: Colors.white70,
        ),
      ),
      actions: [
        Expanded(
          child: Center(
            child: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                child: Text("No thanks", style: dialogButtonStyle()),
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Builder(
              builder: (ctx) => TextButton(
                onPressed: () {
                  Navigator.of(ctx, rootNavigator: true).pop();
                  _generateFakePOIs();
                },
                child: Text(
                  "Generate",
                  style: dialogButtonStyle(confirm: true),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Check which unvisited POI is closest and update nearestPOI
  // Uses a version counter so only the latest call's result is applied, so stale concurrent calls are discarded
  Future<void> _refreshClosestCheckinPOI() async {
    if (userLocation == null) return;
    final version = ++_refreshVersion;

    final closest = await _poiService.getClosestCheckInPOI(
      nearbyPOIs,
      userLocation!.latitude,
      userLocation!.longitude,
      30, // 30 meters max check-in distance
    );

    if (!mounted || version != _refreshVersion) return;
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
        final levelBefore = ref.read(userDataProvider).value!.level;
        if (result['new_level'] != null) {
          final newLevel = result['new_level'] as int;
          if (levelBefore < 3 && newLevel >= 3) {
            FirebaseAnalytics.instance.logEvent(name: 'reached_level_3');
          }
          ref
              .read(userDataProvider.notifier)
              .patch(
                (u) => u.copyWith(
                  level: newLevel,
                  expPoints: result['new_exp'] ?? u.expPoints,
                ),
              );
        } else if (result['new_exp'] != null) {
          ref
              .read(userDataProvider.notifier)
              .patch((u) => u.copyWith(expPoints: result['new_exp'] as int));
        }
        if (mounted) {
          await handleLevelUpOverlay(context, levelBefore, appColor, ref);
        }

        setState(() {
          xpAwarded = result['xp_gained']; // show XP in the button briefly
          checkingIn = false;
        });

        checkinConfettiController.play(); // confetti celebration

        // After 2 seconds, clear the XP display and refresh nearest POI
        await Future.delayed(const Duration(seconds: 4));
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
            vertical: Responsive.height(context, 10),
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
                      style: GoogleFonts.manrope(
                        color: visited ? Colors.white24 : Colors.white54,
                        fontSize: Responsive.font(context, 12),
                      ),
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
    // Offset pushes the back button down so the card doesn't cover it on mobile
    // Offset pushes buttons down so the card doesn't cover them on mobile
    // Error is just a line of text, skeleton is 4 rows, full POI list is tallest
    double cardOpenMobileOffset = cardIsOpen
        ? (nearbyPOIs.isNotEmpty
              ? 300
              : loadingPOIs
              ? 200
              : poiError != null
              ? 60
              : 300)
        : 0;

    return Scaffold(
      body: Stack(
        children: [
          // THE MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLocation ?? const LatLng(0, 0),
              initialZoom: 15,
              minZoom: 12,
              maxZoom: 19,
              // Restrict panning so the user can't drag the map to another country
              cameraConstraint: _cameraConstraint,
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

              // User location layer (real GPS stream, not used when location is simulated or for guests)
              if (!isGuest && !(_isTestAccount && userLocation != null))
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

              // Hardcoded user marker for the simulated location since CurrentLocationLayer uses real GPS
              if (_isTestAccount && userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLocation!,
                      width: 35,
                      height: 35,
                      child: Container(
                        decoration: BoxDecoration(
                          color: appColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

              // POI markers layer
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Overlay shown before and while location is being retrieved
          if (userLocation == null)
            Container(
              color: Colors.black54,
              child: Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_locationRequested) ...[
                      // Browser requires geolocation to be triggered by a direct user gesture
                      Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: Responsive.scale(context, 48),
                      ),
                      SizedBox(height: Responsive.height(context, 12)),
                      Text(
                        "Tap to find nearby spots",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 18),
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 16)),
                      frostedButton(
                        "Find nearby spots",
                        context,
                        color: appColor,
                        onPressed: () {
                          if (isGuest) {
                            Guest.block(context);
                            return;
                          }
                          setState(() => _locationRequested = true);
                          _initLocation();
                        },
                      ),
                      if (_isTestAccount) ...[
                        SizedBox(height: Responsive.height(context, 12)),
                        frostedButton(
                          "Simulate Location (NYC)",
                          context,
                          color: appColor,
                          onPressed: _simulateLocation,
                        ),
                      ],
                    ] else ...[
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: Responsive.scale(context, 80),
                            height: Responsive.scale(context, 80),
                            child: CircularProgressIndicator(
                              color: Colors.white.withAlpha(40),
                              strokeWidth: Responsive.width(context, 2),
                            ),
                          ),
                          HugeIcon(
                                icon: HugeIcons.strokeRoundedEarth,
                                color: Colors.white70,
                                size: Responsive.scale(context, 40),
                              )
                              .animate(onPlay: (c) => c.repeat())
                              .fadeIn(duration: 700.ms)
                              .then()
                              .fadeOut(duration: 700.ms),
                        ],
                      ),
                      SizedBox(height: Responsive.height(context, 20)),
                      Text(
                            "Retrieving location...",
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 18),
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                          .animate(
                            onPlay: (c) => c.repeat(reverse: true),
                          ) // loops forward then backward
                          .custom(
                            duration: 2000.ms, // 2s per pulse direction
                            curve: Curves.easeInOut,
                            builder: (context, value, child) => Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withAlpha(
                                      (value * 30)
                                          .round(), // max alpha 30, very subtle
                                    ),
                                    blurRadius: Responsive.scale(context, 14),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),

          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top:
                    Responsive.height(context, 25) +
                    (!kIsWeb ? MediaQuery.viewPaddingOf(context).top * 0.5 : 0),
                left: Responsive.height(context, 25),
                right: Responsive.height(context, 25),
                bottom: Responsive.height(context, 25),
              ),
              child: Stack(
                children: [
                  // Back button
                  // On mobile: stays at top until the nearby spots card appears, then instantly jumps down
                  // AnimatedPositioned still handles the smooth slide when the card is opened/closed
                  AnimatedPositioned(
                    duration: _buttonPositionReady
                        ? const Duration(milliseconds: 300)
                        : Duration.zero,
                    curve: Curves.easeInOut,
                    top: Responsive.isDesktop(context)
                        ? Responsive.height(context, 10)
                        : Responsive.isTablet(context)
                        ? Responsive.height(context, 10)
                        : userLocation == null
                        ? Responsive.height(context, 10)
                        : Responsive.height(
                            context,
                            130 + cardOpenMobileOffset,
                          ), // pushed down on mobile to avoid the nearby spots card
                    left: 0,
                    child: GestureDetector(
                      onTap: () => context.go('/'),
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: EdgeInsets.all(
                              Responsive.width(context, 20),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(100),
                              shape: BoxShape.circle,
                            ),
                            child: const Tooltip(
                              message: "Back",
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // THE "NEARBY EXPERIENCE SPOTS" CARD
                  if (userLocation != null)
                    Align(
                      alignment: Alignment.topCenter, // center the widget
                      child: GestureDetector(
                        onTap: () {
                          final generateVisible =
                              (poiError ==
                                      'Location data is unavailable right now.' ||
                                  _usingFakePOIs) &&
                              nearbyPOIs.isEmpty;
                          if (generateVisible) return;
                          setState(() => cardIsOpen = !cardIsOpen);
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 8),
                          ),
                          child: ConstrainedBox(
                            // keeps width consistent without taking full screen
                            constraints: BoxConstraints(
                              maxWidth: Responsive.width(context, 400),
                            ),
                            child: SizedBox(
                              width: double
                                  .infinity, // fill available width so edges align with buttons
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 12,
                                    sigmaY: 12,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 313),
                                    curve: Curves.easeInOut,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(100),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                        Responsive.width(context, 10),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize
                                            .min, // So widget doesn't take the height of the whole screen
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Center(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    "Nearby Spots",
                                                    style: GoogleFonts.manrope(
                                                      fontSize:
                                                          Responsive.width(
                                                            context,
                                                            25,
                                                          ),
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: Responsive.width(
                                                    context,
                                                    10,
                                                  ),
                                                ),
                                                if (!((poiError ==
                                                            'Location data is unavailable right now.' ||
                                                        _usingFakePOIs) &&
                                                    nearbyPOIs.isEmpty))
                                                  Icon(
                                                    cardIsOpen
                                                        ? Icons
                                                              .keyboard_arrow_up
                                                        : Icons
                                                              .keyboard_arrow_down,
                                                    color: Colors.white,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (fillingCache && !cardIsOpen)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                top: Responsive.height(
                                                  context,
                                                  4,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: Responsive.width(
                                                      context,
                                                      12,
                                                    ),
                                                    height: Responsive.width(
                                                      context,
                                                      12,
                                                    ),
                                                    child:
                                                        const CircularProgressIndicator(
                                                          color: Colors.white38,
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                  SizedBox(
                                                    width: Responsive.width(
                                                      context,
                                                      6,
                                                    ),
                                                  ),
                                                  Text(
                                                    "Finding more spots...",
                                                    style: GoogleFonts.manrope(
                                                      color: Colors.white38,
                                                      fontSize:
                                                          Responsive.width(
                                                            context,
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if ((poiError ==
                                                      'Location data is unavailable right now.' ||
                                                  _usingFakePOIs) &&
                                              nearbyPOIs.isEmpty)
                                            Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: Responsive.height(
                                                  context,
                                                  8,
                                                ),
                                                horizontal: Responsive.width(
                                                  context,
                                                  10,
                                                ),
                                              ),
                                              child: Center(
                                                child: MouseRegion(
                                                  cursor:
                                                      SystemMouseCursors.click,
                                                  child: frostedButton(
                                                    "Generate nearby spots",
                                                    context,
                                                    color: appColor,
                                                    onPressed:
                                                        _generateFakePOIs,
                                                    small: true,
                                                  ),
                                                ),
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
                                                    // Only show skeleton when there are no POIs yet
                                                    if (loadingPOIs &&
                                                        nearbyPOIs.isEmpty)
                                                      Skeletonizer(
                                                        enabled: true,
                                                        // Subtle white shimmer to blend with the dark card background
                                                        effect: ShimmerEffect(
                                                          baseColor: Colors
                                                              .white
                                                              .withAlpha(30),
                                                          highlightColor: Colors
                                                              .white
                                                              .withAlpha(15),
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    1200,
                                                              ),
                                                        ),
                                                        // 4 fake POI rows for Skeletonizer
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: List.generate(
                                                            4,
                                                            (_) => Padding(
                                                              padding: EdgeInsets.symmetric(
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
                                                                    color: Colors
                                                                        .white,
                                                                    size: Responsive.width(
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
                                                                            color:
                                                                                Colors.white,
                                                                            fontSize: Responsive.width(
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
                                                                    color: Colors
                                                                        .white38,
                                                                    size: Responsive.width(
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
                                                    // Overpass error is handled by the generate button above the card
                                                    // Other errors (e.g. moving too fast) show inline
                                                    else if (poiError != null &&
                                                        nearbyPOIs.isEmpty)
                                                      Padding(
                                                        padding: EdgeInsets.all(
                                                          Responsive.width(
                                                            context,
                                                            10,
                                                          ),
                                                        ),
                                                        child:
                                                            poiError ==
                                                                'Location data is unavailable right now.'
                                                            ? const SizedBox.shrink()
                                                            : Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Text(
                                                                    poiError!,
                                                                    style: GoogleFonts.manrope(
                                                                      color: Colors
                                                                          .white70,
                                                                      fontSize:
                                                                          Responsive.font(
                                                                            context,
                                                                            13,
                                                                          ),
                                                                    ),
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                  ),
                                                                  SizedBox(
                                                                    height:
                                                                        Responsive.height(
                                                                          context,
                                                                          8,
                                                                        ),
                                                                  ),
                                                                  Center(
                                                                    child: MouseRegion(
                                                                      cursor: SystemMouseCursors
                                                                          .click,
                                                                      child: GestureDetector(
                                                                        onTap: () {
                                                                          if (userLocation !=
                                                                              null) {
                                                                            _loadPOIs(
                                                                              userLocation!.latitude,
                                                                              userLocation!.longitude,
                                                                            );
                                                                          }
                                                                        },
                                                                        child: frostedGlassCard(
                                                                          context,
                                                                          color:
                                                                              appColor,
                                                                          baseRadius:
                                                                              12,
                                                                          padding: EdgeInsets.symmetric(
                                                                            vertical: Responsive.height(
                                                                              context,
                                                                              8,
                                                                            ),
                                                                            horizontal: Responsive.width(
                                                                              context,
                                                                              16,
                                                                            ),
                                                                          ),
                                                                          child: Text(
                                                                            "Try again",
                                                                            style: GoogleFonts.manrope(
                                                                              fontSize: Responsive.font(
                                                                                context,
                                                                                13,
                                                                              ),
                                                                              fontWeight: FontWeight.w600,
                                                                              color: Colors.white,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                      )
                                                    // Show message if no POIs found
                                                    else if (nearbyPOIs.isEmpty)
                                                      Padding(
                                                        padding: EdgeInsets.all(
                                                          Responsive.width(
                                                            context,
                                                            10,
                                                          ),
                                                        ),
                                                        child: Column(
                                                          children: [
                                                            Text(
                                                              isGuest
                                                                  ? "Sign up to explore nearby spots"
                                                                  : "No spots found nearby",
                                                              style: GoogleFonts.manrope(
                                                                color: Colors
                                                                    .white70,
                                                                fontSize:
                                                                    Responsive.width(
                                                                      context,
                                                                      14,
                                                                    ),
                                                              ),
                                                            ),
                                                            if (!isGuest) ...[
                                                              SizedBox(
                                                                height:
                                                                    Responsive.height(
                                                                      context,
                                                                      8,
                                                                    ),
                                                              ),
                                                              Center(
                                                                child: MouseRegion(
                                                                  cursor:
                                                                      SystemMouseCursors
                                                                          .click,
                                                                  child: GestureDetector(
                                                                    onTap:
                                                                        _generateFakePOIs,
                                                                    child: frostedGlassCard(
                                                                      context,
                                                                      color:
                                                                          appColor,
                                                                      baseRadius:
                                                                          12,
                                                                      padding: EdgeInsets.symmetric(
                                                                        vertical:
                                                                            Responsive.height(
                                                                              context,
                                                                              8,
                                                                            ),
                                                                        horizontal: Responsive.width(
                                                                          context,
                                                                          16,
                                                                        ),
                                                                      ),
                                                                      child: Text(
                                                                        "Generate nearby spots",
                                                                        style: GoogleFonts.manrope(
                                                                          fontSize: Responsive.font(
                                                                            context,
                                                                            13,
                                                                          ),
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      )
                                                    // Show the list of POIs in a scrollable container
                                                    else
                                                      ConstrainedBox(
                                                        constraints: BoxConstraints(
                                                          maxHeight:
                                                              Responsive.height(
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
                                                                    EdgeInsets
                                                                        .zero,
                                                                itemCount:
                                                                    nearbyPOIs
                                                                        .length,
                                                                itemBuilder:
                                                                    (
                                                                      context,
                                                                      index,
                                                                    ) {
                                                                      return _poiTile(
                                                                        nearbyPOIs[index],
                                                                      );
                                                                    },
                                                              ),
                                                            ),
                                                            // Show a small loading indicator while the cache is being filled
                                                            if (fillingCache)
                                                              Padding(
                                                                padding: EdgeInsets.symmetric(
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
                                                                      width: Responsive.width(
                                                                        context,
                                                                        14,
                                                                      ),
                                                                      height: Responsive.width(
                                                                        context,
                                                                        14,
                                                                      ),
                                                                      child: const CircularProgressIndicator(
                                                                        color: Colors
                                                                            .white38,
                                                                        strokeWidth:
                                                                            2,
                                                                      ),
                                                                    ),
                                                                    SizedBox(
                                                                      width: Responsive.width(
                                                                        context,
                                                                        8,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      "Finding more spots...",
                                                                      style: GoogleFonts.manrope(
                                                                        color: Colors
                                                                            .white38,
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
                                                  ] else if (poiError !=
                                                          'Location data is unavailable right now.' &&
                                                      !_usingFakePOIs)
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
                                                          style: GoogleFonts.manrope(
                                                            color:
                                                                Colors.white70,
                                                            fontSize:
                                                                Responsive.font(
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
                      ),
                    ),
                  // CHECK-IN BUTTON (only visible when near an unvisited POI)
                  if (nearestPOI != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 140),
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.width(context, 16),
                                    vertical: Responsive.height(context, 10),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(100),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        POIIcons.fromCategory(
                                          _tappedPOI!.category,
                                        ),
                                        color: Colors.white,
                                        size: Responsive.width(context, 22),
                                      ),
                                      SizedBox(
                                        width: Responsive.width(context, 8),
                                      ),
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
                                                fontSize: Responsive.font(
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
                                                fontSize: Responsive.font(
                                                  context,
                                                  13,
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () async {
                                                final lat = _tappedPOI!.lat;
                                                final lng = _tappedPOI!.lng;
                                                final name = _tappedPOI!.name;
                                                if (kIsWeb) {
                                                  // map_launcher doesn't support web, fall back to Google Maps
                                                  launchUrl(
                                                    Uri.parse(
                                                      'https://www.google.com/maps/@$lat,$lng,17z/search/${Uri.encodeComponent(name)}',
                                                    ),
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                  return;
                                                }
                                                final maps = await MapLauncher
                                                    .installedMaps;
                                                if (!mounted) return;
                                                if (maps.length == 1) {
                                                  // only one maps app installed, launch it directly
                                                  maps.first.showMarker(
                                                    coords: Coords(lat, lng),
                                                    title: name,
                                                  );
                                                } else {
                                                  // show a picker with all installed maps
                                                  showFrostedAlertDialog(
                                                    context: context,
                                                    appColor: appColor,
                                                    title: 'Open in Maps',
                                                    actions: [
                                                      for (final map in maps)
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                            map.showMarker(
                                                              coords: Coords(
                                                                lat,
                                                                lng,
                                                              ),
                                                              title: name,
                                                            );
                                                          },
                                                          child: Text(
                                                            map.mapName,
                                                          ),
                                                        ),
                                                    ],
                                                  );
                                                }
                                              },
                                              child: Text(
                                                'Open in Maps',
                                                style: GoogleFonts.manrope(
                                                  color: Colors.lightBlueAccent,
                                                  fontSize: Responsive.font(
                                                    context,
                                                    12,
                                                  ),
                                                  fontWeight: FontWeight.w600,
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
                            ), // pushed down on mobile to avoid the nearby spots card
                      right: Responsive.width(
                        context,
                        8,
                      ), // matches the card's horizontal padding

                      child: GestureDetector(
                        onTap: () =>
                            _mapController.move(userLocation!, _currentZoom),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: EdgeInsets.all(
                                Responsive.width(context, 20),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(100),
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
                      ),
                    ),

                  // CONFETTI positioned above screen so particles enter from off-screen
                  Positioned(
                    top: -Responsive.height(context, 20),
                    left: 0,
                    right: 0,
                    child: Center(child: buildCheckinConfetti()),
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
