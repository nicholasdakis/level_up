import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import '../services/user_data_manager.dart';
import '../providers/app_ready_provider.dart';
import '../services/leaderboard_service.dart';

final _facebookAppEvents = FacebookAppEvents();

// Global leaderboard_service object
final leaderboardService = LeaderboardService();

const Duration dailyRewardCooldown = Duration(hours: 23);
const Duration snackBarDuration = Duration(milliseconds: 1500);
const Duration snackBarDurationImportant = Duration(seconds: 3);

// assigned in main() once ProviderScope is available; stub prevents LateInitializationError on hot restart
AppReadyNotifier appReadyNotifier = AppReadyNotifier();

// set to true by AppInitScreen once init completes, reset to false on logout
bool appInitialized = false;

// set to true when the app version is below the minimum required
bool isAppOutdated = false;

// Captured in main() before runApp so the original browser URL is preserved
Uri appLaunchUri = Uri();

// set to true when the user chooses "Continue as Guest", skips auth and backend writes
bool isGuest = false;

// set to true while a Google Sign-In TOS check is in progress, suppresses router redirect
bool suppressAuthRedirect = false;

// Notifies go_router to re-run redirect when guest state changes
ValueNotifier<bool> guestNotifier = ValueNotifier<bool>(false);

// updated by the JS visualViewport resize listener so dialogs shift up on iOS PWA keyboard open
ValueNotifier<double> viewportHeightNotifier = ValueNotifier<double>(0);

// set after onboarding to show a contextual hint on the destination screen
ValueNotifier<String?> onboardingHintNotifier = ValueNotifier<String?>(null);

// active when the user previewed a theme color from the premium sheet without subscribing
// holds the original color to restore when the timer expires
typedef PremiumPreview = ({Color originalColor, DateTime expiresAt});
ValueNotifier<PremiumPreview?> premiumPreviewNotifier =
    ValueNotifier<PremiumPreview?>(null);

final UserDataManager userManager =
    UserDataManager(); // global current user manager variable (not Firestore-dependent)

// Logs a named analytics event, skipped for guests and the developer account to avoid skewing data
void logAnalyticsEvent(String name, {Map<String, Object>? parameters}) {
  if (isGuest) return;
  if (kDebugMode) return;
  if (FirebaseAuth.instance.currentUser?.email == 'n1ch0lasd4k1s@gmail.com') {
    return;
  }
  FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
}

// Logs a named Facebook event, skipped for guests and the developer account
void logFacebookEvent(String name, {Map<String, Object?>? parameters}) {
  if (isGuest) return;
  if (kDebugMode) return;
  if (FirebaseAuth.instance.currentUser?.email == 'n1ch0lasd4k1s@gmail.com') {
    return;
  }
  _facebookAppEvents.logEvent(name: name, parameters: parameters);
}

// Logs the Facebook Purchase standard event
void logFacebookPurchase({required double amount, required String currency}) {
  if (kDebugMode) return;
  if (FirebaseAuth.instance.currentUser?.email == 'n1ch0lasd4k1s@gmail.com') {
    return;
  }
  _facebookAppEvents.logPurchase(amount: amount, currency: currency);
}

// Logs the Facebook CompleteRegistration standard event
void logFacebookSignUp(String method) {
  if (kDebugMode) return;
  if (FirebaseAuth.instance.currentUser?.email == 'n1ch0lasd4k1s@gmail.com') {
    return;
  }
  _facebookAppEvents.logCompletedRegistration(registrationMethod: method);
}
