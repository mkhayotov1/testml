/*
 * File: lib/services/face_detector_service.dart
 *
 * Purpose:
 * Wrapper around Google ML Kit Face Detection API. Detects faces in an image
 * and extracts bounding box coordinates for face cropping.
 *
 * Connected Files:
 * - Injected into [FaceRecognitionBloc] in `lib/bloc/face_recognition_bloc.dart`.
 * - Instantiated inside [FaceRecognitionHomeWrapper] in `lib/ui/face_recognition_home.dart`.
 */

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorService {
  late final FaceDetector _faceDetector;

  FaceDetectorService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: false,
        enableClassification: false,
        minFaceSize: 0.15,
      ),
    );
  }

  Future<List<Face>> detectFaces(InputImage inputImage) async {
    return await _faceDetector.processImage(inputImage);
  }

  void dispose() {
    _faceDetector.close();
  }
}
