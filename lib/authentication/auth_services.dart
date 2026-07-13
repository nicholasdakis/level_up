import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_data_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/food_logs_provider.dart';
import '../providers/water_logs_provider.dart';
import '../providers/weight_logs_provider.dart';
import '../services/user_data_manager.dart';
import '../guest.dart';
import '../services/fcm/web_fcm_token_stub.dart'
    if (dart.library.js_interop) '../services/fcm/web_fcm_token_web.dart'
    as web_fcm;

ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  User? get currentUser => firebaseAuth.currentUser;

  Stream<User?> get authStateChanges =>
      firebaseAuth.authStateChanges(); // to see if user is connected

  Future<void> signOut(
    UserDataNotifierNew notifier,
    WorkoutNotifier workoutNotifier, {
    WidgetRef? ref,
  }) async {
    if (isGuest) {
      ref?.invalidate(foodLogsProvider);
      ref?.invalidate(waterLogsProvider);
      ref?.invalidate(weightLogsProvider);
      ref?.invalidate(workoutProvider);
      Guest.exit();
      return;
    }
    // Remove only this device's FCM token so notifications stop on this device
    try {
      final deviceToken = kIsWeb
          ? await web_fcm.getWebFcmToken(fcmVapidKey)
          : await FirebaseMessaging.instance.getToken();
      if (deviceToken != null) {
        await notifier.removeFcmToken(deviceToken);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error removing FCM token during signOut: $e');
    }

    workoutNotifier.clearSession();
    ref?.invalidate(foodLogsProvider);
    ref?.invalidate(waterLogsProvider);
    ref?.invalidate(weightLogsProvider);
    ref?.invalidate(workoutProvider);
    await firebaseAuth.signOut();
    appInitialized = false;
    appReadyNotifier.reset();
    notifier.setUserData(null);
  }

  // CONTINUE WITH GOOGLE BUTTON

  // On native: checks if the user exists in Supabase BEFORE signing into Firebase
  // so new users never enter the app without accepting TOS
  Future<UserCredential?> signInWithGoogle({bool agreedToTerms = false}) async {
    // Web check
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.setCustomParameters({'prompt': 'select_account'});
      suppressAuthRedirect = true;
      try {
        final user = firebaseAuth.currentUser;
        final email = user?.email;
        if (agreedToTerms && user != null && email != null) {
          // TOS accepted and already signed in from previous popup — just register and proceed
          suppressAuthRedirect = false;
          return null;
        }
        final result = await firebaseAuth.signInWithPopup(googleProvider);
        final resultEmail = result.user?.email;
        if (resultEmail != null) {
          final response = await http
              .post(
                Uri.parse('$backendBaseUrl/check_user_email_exists'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'email': resultEmail}),
              )
              .timeout(const Duration(seconds: 5));
          final exists = jsonDecode(response.body)['exists'] == true;
          if (!exists && !agreedToTerms) {
            await firebaseAuth.signOut();
            throw FirebaseAuthException(code: 'new-user-no-tos');
          }
        }
        suppressAuthRedirect = false;
        return result;
      } catch (e) {
        if (e is! FirebaseAuthException || e.code != 'new-user-no-tos') {
          suppressAuthRedirect = false;
        }
        rethrow;
      }
      // Native check
    } else {
      // Native Android/iOS uses the google_sign_in package to show the native account picker
      // Sign out first so the account picker always appears instead of auto-signing into the last used account
      final gsi = GoogleSignIn();
      await gsi.signOut();
      final googleUser = await gsi.signIn();
      if (googleUser == null) return null; // user cancelled

      // Check by email before touching Firebase — no auth state change for new users
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/check_user_email_exists'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': googleUser.email}),
          )
          .timeout(const Duration(seconds: 5));

      final body = jsonDecode(response.body);
      final exists = body['exists'] == true;
      if (!exists && !agreedToTerms) {
        throw FirebaseAuthException(code: 'new-user-no-tos');
      }

      // User exists or TOS accepted — safe to sign into Firebase
      if (!exists) {
        await FirebaseAnalytics.instance.logSignUp(signUpMethod: 'google.com');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await firebaseAuth.signInWithCredential(credential);
    }
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    // Create the user in Firebase Auth, refresh the user, and return the credential
    final credential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await FirebaseAuth.instance.currentUser!.reload();
    await FirebaseAnalytics.instance.logSignUp(signUpMethod: 'email');
    return credential;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> resetPassword({required String email}) async {
    await firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.updatePassword(newPassword);
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.delete();
    await firebaseAuth.signOut();
  }
}
