// File generated for Firebase configuration
// Contains platform-specific Firebase options

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCCOlX6mV1rU53W5sYaeeWktVx4UXnmyYs',
    appId: '1:641549516220:web:4f4009ea3937cc86e8ffb9',
    messagingSenderId: '641549516220',
    projectId: 'notes-b9afa',
    authDomain: 'notes-b9afa.firebaseapp.com',
    storageBucket: 'notes-b9afa.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC8lwYHQUkAzDbagLIPkHO9gwYhnwZYTJw',
    appId: '1:641549516220:android:dfa8addeb835211be8ffb9',
    messagingSenderId: '641549516220',
    projectId: 'notes-b9afa',
    storageBucket: 'notes-b9afa.firebasestorage.app',
  );

  // iOS configuration - add your iOS config here when available
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: '641549516220',
    projectId: 'notes-b9afa',
    storageBucket: 'notes-b9afa.firebasestorage.app',
    iosBundleId: 'com.souaib.notes',
  );

  // macOS configuration
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: '641549516220',
    projectId: 'notes-b9afa',
    storageBucket: 'notes-b9afa.firebasestorage.app',
    iosBundleId: 'com.souaib.notes',
  );

  // Windows configuration
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCCOlX6mV1rU53W5sYaeeWktVx4UXnmyYs',
    appId: '1:641549516220:web:4f4009ea3937cc86e8ffb9',
    messagingSenderId: '641549516220',
    projectId: 'notes-b9afa',
    authDomain: 'notes-b9afa.firebaseapp.com',
    storageBucket: 'notes-b9afa.firebasestorage.app',
  );
}
