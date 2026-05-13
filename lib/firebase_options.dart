import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not configured for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB8-LcNsCV14vSnEZhZk08XCW7ONTS4xmY',
    appId: '1:888637651520:web:3186576a7959b27009fda5',
    messagingSenderId: '888637651520',
    projectId: 'studnetovercooked',
    authDomain: 'studnetovercooked.firebaseapp.com',
    storageBucket: 'studnetovercooked.firebasestorage.app',
    databaseURL: 'https://studnetovercooked-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB8-LcNsCV14vSnEZhZk08XCW7ONTS4xmY',
    appId: '1:888637651520:android:3186576a7959b27009fda5',
    messagingSenderId: '888637651520',
    projectId: 'studnetovercooked',
    storageBucket: 'studnetovercooked.firebasestorage.app',
    databaseURL: 'https://studnetovercooked-default-rtdb.europe-west1.firebasedatabase.app',
  );
}
