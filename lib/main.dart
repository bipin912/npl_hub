import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Required before initializing Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  // Connect to Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase App Check.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: AndroidDebugProvider(),
  );

  // Start the Flutter application.
  runApp(const NplCommunityApp());
}