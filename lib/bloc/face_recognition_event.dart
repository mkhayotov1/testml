/*
 * File: lib/bloc/face_recognition_event.dart
 *
 * Purpose:
 * Defines all user actions and system trigger events for the Face Recognition BLoC
 * (e.g. initialize model, pick image, compare faces, load samples, register face, recognize face).
 *
 * Connected Files:
 * - Handled by [FaceRecognitionBloc] in `lib/bloc/face_recognition_bloc.dart`.
 * - Dispatched from [FaceRecognitionHome] UI in `lib/ui/face_recognition_home.dart`.
 */

import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

abstract class FaceRecognitionEvent extends Equatable {
  const FaceRecognitionEvent();

  @override
  List<Object?> get props => [];
}

class InitializeModelEvent extends FaceRecognitionEvent {
  const InitializeModelEvent();
}

class PickCompareImageEvent extends FaceRecognitionEvent {
  final int targetIndex; // 1 or 2
  final ImageSource source;

  const PickCompareImageEvent({
    required this.targetIndex,
    required this.source,
  });

  @override
  List<Object?> get props => [targetIndex, source];
}

class LoadSampleCompareImagesEvent extends FaceRecognitionEvent {
  final bool samePerson;

  const LoadSampleCompareImagesEvent({required this.samePerson});

  @override
  List<Object?> get props => [samePerson];
}

class CompareFacesEvent extends FaceRecognitionEvent {
  const CompareFacesEvent();
}

class RegisterFaceEvent extends FaceRecognitionEvent {
  final String name;
  final ImageSource source;

  const RegisterFaceEvent({
    required this.name,
    required this.source,
  });

  @override
  List<Object?> get props => [name, source];
}

class RegisterSampleFacesEvent extends FaceRecognitionEvent {
  const RegisterSampleFacesEvent();
}

class RecognizeFaceEvent extends FaceRecognitionEvent {
  final ImageSource source;

  const RecognizeFaceEvent({required this.source});

  @override
  List<Object?> get props => [source];
}

class DeleteRegisteredFaceEvent extends FaceRecognitionEvent {
  final String id;

  const DeleteRegisteredFaceEvent({required this.id});

  @override
  List<Object?> get props => [id];
}
