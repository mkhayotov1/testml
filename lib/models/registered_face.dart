/*
 * File: lib/models/registered_face.dart
 *
 * Purpose:
 * Represents a registered person record, encapsulating unique ID, person name,
 * extracted face feature embedding vector, and photo path.
 *
 * Connected Files:
 * - Used by [FaceRecognitionState] in `lib/bloc/face_recognition_state.dart`.
 * - Managed by [FaceRecognitionBloc] in `lib/bloc/face_recognition_bloc.dart`.
 * - Rendered in [FaceRecognitionHome] in `lib/ui/face_recognition_home.dart`.
 */

class RegisteredFace {
  final String id;
  final String name;
  final List<double> embedding;
  final String? imagePath;

  RegisteredFace({
    required this.id,
    required this.name,
    required this.embedding,
    this.imagePath,
  });
}
