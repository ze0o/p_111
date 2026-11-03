// Firebase configuration for the app.
//
// These values identify the Firebase project to the client SDKs. They are not
// secrets: access to data is controlled by Firebase Authentication and the
// Firestore / Storage security rules, not by hiding this file.
//
// To point the app at your own Firebase project, run `flutterfire configure`,
// which regenerates this file with per-platform options.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  /// Options used on every platform. The project currently ships a single web
  /// app registration; add platform-specific options here (or regenerate this
  /// file with `flutterfire configure`) when registering Android/iOS apps.
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBrPvKdNX28B85l9ynlecMYrHRYskFjHGc',
    authDomain: 'itcs444-proj.firebaseapp.com',
    projectId: 'itcs444-proj',
    storageBucket: 'itcs444-proj.appspot.com',
    messagingSenderId: '603532184988',
    appId: '1:603532184988:web:a5c386220a3d5878024c59',
    measurementId: 'G-KMNRLWK9X6',
  );
}
