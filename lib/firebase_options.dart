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
    apiKey: 'AIzaSyArqjm6XJ5QydLO78mahTz3bXNpUQWa9iE',
    appId: "1:220369859979:web:05a584ffc0c07a1955ab8e",
    messagingSenderId: "220369859979",
    projectId: "firstfb-48a7c",
    databaseURL: "https://firstfb-48a7c-default-rtdb.europe-west1.firebasedatabase.app/",
  );

}
