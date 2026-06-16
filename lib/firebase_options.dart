// Firebase web/app configuration for project "chicken-hunter-35042".
// These web config values are public client identifiers (safe to commit) —
// Firebase secures data via Authentication + Firestore Security Rules, not by
// hiding these keys. If GitHub secrets are set, CI overwrites this at build.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('Unsupported platform for Firebase');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB_ph8U__xfnl9djASO4Wq9ZVKMr6oEk5I',
    appId: '1:880315665778:web:2d3e41488e3465d43f21eb',
    messagingSenderId: '880315665778',
    projectId: 'chicken-hunter-35042',
    authDomain: 'chicken-hunter-35042.firebaseapp.com',
    storageBucket: 'chicken-hunter-35042.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB_ph8U__xfnl9djASO4Wq9ZVKMr6oEk5I',
    appId: '1:880315665778:web:2d3e41488e3465d43f21eb',
    messagingSenderId: '880315665778',
    projectId: 'chicken-hunter-35042',
    storageBucket: 'chicken-hunter-35042.firebasestorage.app',
  );
}
