/*
 * File: lib/bloc/face_recognition_bloc.dart
 *
 * Purpose:
 * Central Business Logic Component for Face Recognition. Orchestrates image picking,
 * face detection via [FaceDetectorService], TFLite embedding extraction and distance
 * metrics via [FaceRecognizerService], sample faces loading, and emits immutable [FaceRecognitionState] updates.
 *
 * Connected Files:
 * - Receives [FaceRecognitionEvent] from `lib/bloc/face_recognition_event.dart`.
 * - Emits [FaceRecognitionState] defined in `lib/bloc/face_recognition_state.dart`.
 * - Uses [FaceDetectorService] in `lib/services/face_detector_service.dart`.
 * - Uses [FaceRecognizerService] in `lib/services/face_recognizer_service.dart`.
 * - Provided to UI in `lib/ui/face_recognition_home.dart`.
 */

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../models/registered_face.dart';
import '../services/face_detector_service.dart';
import '../services/face_recognizer_service.dart';
import 'face_recognition_event.dart';
import 'face_recognition_state.dart';

class FaceRecognitionBloc extends Bloc<FaceRecognitionEvent, FaceRecognitionState> {
  final FaceDetectorService detectorService;
  final FaceRecognizerService recognizerService;
  final ImagePicker _picker = ImagePicker();

  FaceRecognitionBloc({
    required this.detectorService,
    required this.recognizerService,
  }) : super(const FaceRecognitionState()) {
    on<InitializeModelEvent>(_onInitializeModel);
    on<PickCompareImageEvent>(_onPickCompareImage);
    on<LoadSampleCompareImagesEvent>(_onLoadSampleCompareImages);
    on<CompareFacesEvent>(_onCompareFaces);
    on<RegisterFaceEvent>(_onRegisterFace);
    on<RegisterSampleFacesEvent>(_onRegisterSampleFaces);
    on<RecognizeFaceEvent>(_onRecognizeFace);
    on<DeleteRegisteredFaceEvent>(_onDeleteRegisteredFace);
  }

  Future<void> _onInitializeModel(
    InitializeModelEvent event,
    Emitter<FaceRecognitionState> emit,
  ) async {
    emit(state.copyWith(
      isModelLoading: true,
      statusMessage: 'Loading FaceNet TFLite model...',
    ));

    await recognizerService.loadModel();

    emit(state.copyWith(
      isModelLoading: false,
      isModelLoaded: recognizerService.isLoaded,
      statusMessage: recognizerService.isLoaded
          ? 'TFLite Model Ready (${recognizerService.inputSize}x${recognizerService.inputSize} Input, ${recognizerService.embeddingDim}D Vector)'
          : 'Failed to load TFLite Model!',
    ));
  }

  Future<File> _loadAssetToTempFile(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/${assetPath.split('/').last}');
    await file.writeAsBytes(byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    ));
    return file;
  }

  Future<img.Image?> _processAndExtractFace(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final faces = await detectorService.detectFaces(inputImage);

    if (faces.isEmpty) return null;

    final imageBytes = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) return null;

    Face primaryFace = faces.first;
    double maxArea = primaryFace.boundingBox.width * primaryFace.boundingBox.height;

    for (var face in faces) {
      final area = face.boundingBox.width * face.boundingBox.height;
      if (area > maxArea) {
        maxArea = area;
        primaryFace = face;
      }
    }

    final box = primaryFace.boundingBox;
    final x = box.left.toInt().clamp(0, decodedImage.width - 1);
    final y = box.top.toInt().clamp(0, decodedImage.height - 1);
    final w = box.width.toInt().clamp(1, decodedImage.width - x);
    final h = box.height.toInt().clamp(1, decodedImage.height - y);

    return img.copyCrop(decodedImage, x: x, y: y, width: w, height: h);
  }

  Future<void> _onPickCompareImage(
    PickCompareImageEvent event,
    Emitter<FaceRecognitionState> emit,
  ) async {
    final pickedFile = await _picker.pickImage(source: event.source);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    if (event.targetIndex == 1) {
      emit(state.copyWith(
        image1: file,
        clearCroppedFace1: true,
        clearDistance: true,
        clearSimilarity: true,
        clearToastMessage: true,
      ));
    } else {
      emit(state.copyWith(
        image2: file,
        clearCroppedFace2: true,
        clearDistance: true,
        clearSimilarity: true,
        clearToastMessage: true,
      ));
    }

    add(const CompareFacesEvent());
  }

  Future<void> _onLoadSampleCompareImages(
    LoadSampleCompareImagesEvent event,
    Emitter<FaceRecognitionState> emit,
  ) async {
    try {
      emit(state.copyWith(isComparing: true));

      final file1 = await _loadAssetToTempFile('assets/sample_faces/person1_photo1.jpg');
      final file2 = event.samePerson
          ? await _loadAssetToTempFile('assets/sample_faces/person1_photo2.jpg')
          : await _loadAssetToTempFile('assets/sample_faces/person2_photo1.jpg');

      emit(state.copyWith(
        image1: file1,
        image2: file2,
        clearCroppedFace1: true,
        clearCroppedFace2: true,
        clearDistance: true,
        clearSimilarity: true,
        clearToastMessage: true,
      ));

      add(const CompareFacesEvent());
    } catch (e) {
      emit(state.copyWith(
        isComparing: false,
        toastMessage: 'Failed to load sample images: $e',
      ));
    }
  }

  Future<void> _onCompareFaces(
    CompareFacesEvent event,
    Emitter<FaceRecognitionState> emit,
  ) async {
    if (state.image1 == null || state.image2 == null) return;

    emit(state.copyWith(isComparing: true));

    try {
      final cropped1 = await _processAndExtractFace(state.image1!);
      final cropped2 = await _processAndExtractFace(state.image2!);

      if (cropped1 == null || cropped2 == null) {
        final msg = cropped1 == null && cropped2 == null
            ? 'No faces detected in either image!'
            : (cropped1 == null
                ? 'No face detected in Image 1!'
                : 'No face detected in Image 2!');

        emit(state.copyWith(
          isComparing: false,
          toastMessage: msg,
        ));
        return;
      }

      final emb1 = recognizerService.extractEmbedding(cropped1);
      final emb2 = recognizerService.extractEmbedding(cropped2);

      final dist = recognizerService.calculateEuclideanDistance(emb1, emb2);
      final sim = recognizerService.calculateCosineSimilarity(emb1, emb2);

      emit(state.copyWith(
        croppedFace1: cropped1,
        croppedFace2: cropped2,
        euclideanDistance: dist,
        similarityScore: sim,
        isComparing: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isComparing: false,
        toastMessage: 'Error comparing faces: $e',
      ));
    }
  }

  Future<void> _onRegisterFace(
    RegisterFaceEvent event,
    Emitter<FaceRecognitionState> emit,
  ) async {
    final pickedFile = await _picker.pickImage(source: event.source);
    if (pickedFile == null) return;

    emit(state.copyWith(isRegistering: true));

    try {
      final file = File(pickedFile.path);
      final croppedFace = await _processAndExtractFace(file);

      if (croppedFace == null) {
        emit(state.copyWith(
          isRegistering: false,
          toastMessage: 'No face detected in selected image!',
        ));
        return;
      }

      final embedding = recognizerService.extractEmbedding(croppedFace);

      final newFace = RegisteredFace(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: event.name,
        embedding: embedding,
        imagePath: pickedFile.path,
      );

      final updatedList = List<RegisteredFace>.from(state.registeredFaces)..add(newFace);

      emit(state.copyWith(
        registeredFaces: updatedList,
        isRegistering: false,
        toastMessage: 'Registered "${event.name}" successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isRegistering: false,
        toastMessage: 'Error registering face: $e',
      ));
    }
  }

  Future<void> _onRegisterSampleFaces(
    RegisterSampleFacesEvent event,
    Emitter<FaceRecognitionState> emit,
  ) async {
    emit(state.copyWith(isRegistering: true));

    try {
      final file1 = await _loadAssetToTempFile('assets/sample_faces/person1_photo1.jpg');
      final file2 = await _loadAssetToTempFile('assets/sample_faces/person2_photo1.jpg');

      final cropped1 = await _processAndExtractFace(file1);
      final cropped2 = await _processAndExtractFace(file2);

      if (cropped1 == null || cropped2 == null) {
        emit(state.copyWith(
          isRegistering: false,
          toastMessage: 'Failed to detect faces in sample images!',
        ));
        return;
      }

      final emb1 = recognizerService.extractEmbedding(cropped1);
      final emb2 = recognizerService.extractEmbedding(cropped2);

      final sample1 = RegisteredFace(
        id: 'sample_alex_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Alex (Sample)',
        embedding: emb1,
        imagePath: file1.path,
      );

      final sample2 = RegisteredFace(
        id: 'sample_sophia_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Sophia (Sample)',
        embedding: emb2,
        imagePath: file2.path,
      );

      final updatedList = List<RegisteredFace>.from(state.registeredFaces)
        ..add(sample1)
        ..add(sample2);

      emit(state.copyWith(
        registeredFaces: updatedList,
        isRegistering: false,
        toastMessage: 'Loaded sample faces "Alex" & "Sophia" into database!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isRegistering: false,
        toastMessage: 'Error registering sample faces: $e',
      ));
    }
  }

  Future<void> _onRecognizeFace(
    RecognizeFaceEvent event,
    Emitter<FaceRecognitionState> emit,
  ) async {
    if (state.registeredFaces.isEmpty) {
      emit(state.copyWith(
        toastMessage: 'Please register at least one face first!',
      ));
      return;
    }

    final pickedFile = await _picker.pickImage(source: event.source);
    if (pickedFile == null) return;

    emit(state.copyWith(
      isRecognizing: true,
      clearRecognitionResult: true,
      clearRecognitionConfidence: true,
    ));

    try {
      final file = File(pickedFile.path);
      final croppedFace = await _processAndExtractFace(file);

      if (croppedFace == null) {
        emit(state.copyWith(
          isRecognizing: false,
          toastMessage: 'No face detected in target image!',
        ));
        return;
      }

      final queryEmbedding = recognizerService.extractEmbedding(croppedFace);

      RegisteredFace? bestMatch;
      double minDistance = double.infinity;
      double maxSimilarity = -1.0;

      for (var regFace in state.registeredFaces) {
        final dist = recognizerService.calculateEuclideanDistance(
          queryEmbedding,
          regFace.embedding,
        );
        final sim = recognizerService.calculateCosineSimilarity(
          queryEmbedding,
          regFace.embedding,
        );

        if (dist < minDistance) {
          minDistance = dist;
          maxSimilarity = sim;
          bestMatch = regFace;
        }
      }

      final isMatch = minDistance < 1.0 || maxSimilarity > 0.65;

      emit(state.copyWith(
        isRecognizing: false,
        recognitionResult: isMatch && bestMatch != null
            ? bestMatch.name
            : 'Unknown Face',
        recognitionConfidence: maxSimilarity.clamp(0.0, 1.0),
      ));
    } catch (e) {
      emit(state.copyWith(
        isRecognizing: false,
        toastMessage: 'Error recognizing face: $e',
      ));
    }
  }

  void _onDeleteRegisteredFace(
    DeleteRegisteredFaceEvent event,
    Emitter<FaceRecognitionState> emit,
  ) {
    final updatedList = state.registeredFaces.where((f) => f.id != event.id).toList();
    emit(state.copyWith(registeredFaces: updatedList));
  }
}
