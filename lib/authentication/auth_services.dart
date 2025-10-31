import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  User? get currentUser => firebaseAuth.currentUser;
  Stream<User?> get authStateChanges =>
      firebaseAuth.authStateChanges(); // to see if user is connected
  // SIGNING OUT
  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }

  // SIGNING UP WITH EMAIL AND PASSWORD
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    // 1. Create the user in Firebase Auth
    final credential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 2. Refresh the user after account creation
    await FirebaseAuth.instance.currentUser!.reload();

    // 3. Store this user into the Firestore database
    final uid = credential.user!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'username': uid, // default username = UID
      'level': 1, // starting level
      'expPoints': 0, // starting XP
      'pfpBase64': null, // no profile picture yet
    });

    // 3. Return the Auth credential
    return credential;
  }

  // SIGNING IN WITH EMAIL AND PASSWORD
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // RESETTING PASSWORD
  Future<void> resetPassword({required String email}) async {
    await firebaseAuth.sendPasswordResetEmail(email: email);
  }

  // UPDATING PASSWORD
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

  // UPDATING USERNAME
  Future<void> updateUsername({required String username}) async {
    await currentUser!.updateDisplayName(username);
  }

  // DELETING ACCOUNT
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

// TODO: sign up/in with Google or with phone number
