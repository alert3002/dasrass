// Сгенерировано из google-services.json и GoogleService-Info.plist
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static bool get isConfigured => true;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web push is not configured.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Push is not configured for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCR5FEKSamBV6O6zD_8gd76Ki3gcS-hMKw',
    appId: '1:1047661994555:android:03e41238ac13cb607d321e',
    messagingSenderId: '1047661994555',
    projectId: 'comdastrass',
    storageBucket: 'comdastrass.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA9j1V2geBkgj_mfZSRFAb32AyP5VOfgkg',
    appId: '1:1047661994555:ios:f89d6e0b2d7670d57d321e',
    messagingSenderId: '1047661994555',
    projectId: 'comdastrass',
    storageBucket: 'comdastrass.firebasestorage.app',
    iosBundleId: 'com.dastrass.dastrassApp',
  );
}
