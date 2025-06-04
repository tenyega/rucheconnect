import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;




/// I have loaded the firebase_core library and from this library i m using only FirebaseOptions.
/// From the library of flutter i m taking the library foundation.dart and inside which i m loading only defaultTargetPlatform and TargetPlatform for this project.
/// HEre i have defined a class called DefaultFirebaseOptions where i m checking the current connected platform, for my this mobile app i m handling only android phone
/// For the FirebaseOptions class it needs all the parameter of connection to the firebase project.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;

      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(

      apiKey: "AIzaSyCz-9yrbpQbxzWQV-eWY3F0xInzbIlRY6g",
      authDomain: "rucheconnect-a4363.firebaseapp.com",
      databaseURL: "https://rucheconnect-a4363-default-rtdb.europe-west1.firebasedatabase.app",
      projectId: "rucheconnect-a4363",
      storageBucket: "rucheconnect-a4363.firebasestorage.app",
      messagingSenderId: "147038649239",
      appId: "1:147038649239:web:0d6b9e38eb48b2a54fa2d2"

  );

}
