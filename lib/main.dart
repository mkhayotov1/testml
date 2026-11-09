/*
 * File: lib/main.dart
 *
 * Purpose:
 * App entry point. Initializes Flutter bindings and boots up the MaterialApp
 * using the BLoC-enabled UI wrapper.
 *
 * Connected Files:
 * - Uses [FaceRecognitionHomeWrapper] in `lib/ui/face_recognition_home.dart`.
 */

import 'package:flutter/material.dart';
import 'ui/face_recognition_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TFLite Face Recognition (BLoC)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const FaceRecognitionHomeWrapper(),
    );
  }
}
