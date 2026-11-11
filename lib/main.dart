import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool ready = false;
  String? error;
  try {
    // Native Android/iOS configuration is bundled by the platform build.
    await Firebase.initializeApp();
    ready = true;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    error = 'Unable to start the app. Please restart and try again.';
  }
  runApp(RajhansApp(firebaseReady: ready, setupError: error));
}
