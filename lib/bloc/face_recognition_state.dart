/*
 * File: lib/bloc/face_recognition_state.dart
 *
 * Purpose:
 * Immutable state class for [FaceRecognitionBloc]. Holds model status, selected images,
 * cropped face previews, distance metrics, registered face database, and toast messages.
 *
 * Connected Files:
 * - Uses [RegisteredFace] in `lib/models/registered_face.dart`.
 * - Emitted by [FaceRecognitionBloc] in `lib/bloc/face_recognition_bloc.dart`.
 * - Consumed by [FaceRecognitionHome] in `lib/ui/face_recognition_home.dart`.
 */

import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:image/image.dart' as img;

import '../models/registered_face.dart';

class FaceRecognitionState extends Equatable {
  final bool isModelLoading;
  final bool isModelLoaded;
  final String statusMessage;

  // Compare Tab State
  final File? image1;
  final File? image2;
  final img.Image? croppedFace1;
  final img.Image? croppedFace2;
  final double? euclideanDistance;
  final double? similarityScore;
  final bool isComparing;

  // Database Tab State
  final List<RegisteredFace> registeredFaces;
  final bool isRegistering;
  final bool isRecognizing;
  final String? recognitionResult;
  final double? recognitionConfidence;

  // Transient notification event
  final String? toastMessage;

  const FaceRecognitionState({
    this.isModelLoading = true,
    this.isModelLoaded = false,
    this.statusMessage = 'Initializing TFLite Model...',
    this.image1,
    this.image2,
    this.croppedFace1,
    this.croppedFace2,
    this.euclideanDistance,
    this.similarityScore,
    this.isComparing = false,
    this.registeredFaces = const [],
    this.isRegistering = false,
    this.isRecognizing = false,
    this.recognitionResult,
    this.recognitionConfidence,
    this.toastMessage,
  });

  FaceRecognitionState copyWith({
    bool? isModelLoading,
    bool? isModelLoaded,
    String? statusMessage,
    File? image1,
    File? image2,
    bool clearImage1 = false,
    bool clearImage2 = false,
    img.Image? croppedFace1,
    img.Image? croppedFace2,
    bool clearCroppedFace1 = false,
    bool clearCroppedFace2 = false,
    double? euclideanDistance,
    bool clearDistance = false,
    double? similarityScore,
    bool clearSimilarity = false,
    bool? isComparing,
    List<RegisteredFace>? registeredFaces,
    bool? isRegistering,
    bool? isRecognizing,
    String? recognitionResult,
    bool clearRecognitionResult = false,
    double? recognitionConfidence,
    bool clearRecognitionConfidence = false,
    String? toastMessage,
    bool clearToastMessage = false,
  }) {
    return FaceRecognitionState(
      isModelLoading: isModelLoading ?? this.isModelLoading,
      isModelLoaded: isModelLoaded ?? this.isModelLoaded,
      statusMessage: statusMessage ?? this.statusMessage,
      image1: clearImage1 ? null : (image1 ?? this.image1),
      image2: clearImage2 ? null : (image2 ?? this.image2),
      croppedFace1:
          clearCroppedFace1 ? null : (croppedFace1 ?? this.croppedFace1),
      croppedFace2:
          clearCroppedFace2 ? null : (croppedFace2 ?? this.croppedFace2),
      euclideanDistance: clearDistance
          ? null
          : (euclideanDistance ?? this.euclideanDistance),
      similarityScore:
          clearSimilarity ? null : (similarityScore ?? this.similarityScore),
      isComparing: isComparing ?? this.isComparing,
      registeredFaces: registeredFaces ?? this.registeredFaces,
      isRegistering: isRegistering ?? this.isRegistering,
      isRecognizing: isRecognizing ?? this.isRecognizing,
      recognitionResult: clearRecognitionResult
          ? null
          : (recognitionResult ?? this.recognitionResult),
      recognitionConfidence: clearRecognitionConfidence
          ? null
          : (recognitionConfidence ?? this.recognitionConfidence),
      toastMessage: clearToastMessage
          ? null
          : (toastMessage ?? this.toastMessage),
    );
  }

  @override
  List<Object?> get props => [
        isModelLoading,
        isModelLoaded,
        statusMessage,
        image1,
        image2,
        croppedFace1,
        croppedFace2,
        euclideanDistance,
        similarityScore,
        isComparing,
        registeredFaces,
        isRegistering,
        isRecognizing,
        recognitionResult,
        recognitionConfidence,
        toastMessage,
      ];
}
