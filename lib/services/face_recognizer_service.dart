/*
 * File: lib/services/face_recognizer_service.dart
 *
 * Purpose:
 * Loads TFLite FaceNet model (`assets/facenet.tflite`) and executes neural network
 * inference to extract feature embeddings. Also computes Euclidean Distance
 * and Cosine Similarity metrics between face vectors.
 *
 * Connected Files:
 * - Model asset loaded from `assets/facenet.tflite`.
 * - Injected into [FaceRecognitionBloc] in `lib/bloc/face_recognition_bloc.dart`.
 * - Instantiated inside [FaceRecognitionHomeWrapper] in `lib/ui/face_recognition_home.dart`.
 */

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognizerService {
  Interpreter? _interpreter;
  int _inputSize = 160;
  int _embeddingDim = 512;
  bool _isQuantized = false;

  bool get isLoaded => _interpreter != null;
  int get inputSize => _inputSize;
  int get embeddingDim => _embeddingDim;

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/facenet.tflite',
        options: options,
      );

      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);

      // Input shape format: [1, height, width, 3]
      if (inputTensor.shape.length == 4) {
        _inputSize = inputTensor.shape[1];
      }

      // Output shape format: [1, embeddingDim]
      if (outputTensor.shape.length == 2) {
        _embeddingDim = outputTensor.shape[1];
      } else if (outputTensor.shape.length == 1) {
        _embeddingDim = outputTensor.shape[0];
      }

      _isQuantized = inputTensor.type == TensorType.uint8 ||
          inputTensor.type == TensorType.int8;

      debugPrint(
        'Model Loaded Successfully! InputSize: $_inputSize, OutputDim: $_embeddingDim, Quantized: $_isQuantized',
      );
    } catch (e) {
      debugPrint('Error loading face recognition model: $e');
    }
  }

  /// Extracts 128/512 dimension face embedding from cropped face image
  List<double> extractEmbedding(img.Image faceImage) {
    if (_interpreter == null) {
      throw Exception('Interpreter not initialized. Call loadModel() first.');
    }

    // 1. Resize image to model input size (e.g. 160x160 or 112x112)
    final resizedImage = img.copyResize(
      faceImage,
      width: _inputSize,
      height: _inputSize,
    );

    // 2. Prepare Float32 / Int input tensor
    final input = Float32List(1 * _inputSize * _inputSize * 3);
    var pixelIndex = 0;

    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final pixel = resizedImage.getPixel(x, y);
        // Normalize image pixels to [-1, 1] range: (pixel - 127.5) / 127.5
        input[pixelIndex++] = (pixel.r - 127.5) / 127.5;
        input[pixelIndex++] = (pixel.g - 127.5) / 127.5;
        input[pixelIndex++] = (pixel.b - 127.5) / 127.5;
      }
    }

    // Reshape input into [1, _inputSize, _inputSize, 3]
    final inputTensor = input.reshape([1, _inputSize, _inputSize, 3]);

    // 3. Output matrix: [1, _embeddingDim]
    final outputTensor = List.generate(
      1,
      (_) => List<double>.filled(_embeddingDim, 0),
    );

    // 4. Run model inference
    _interpreter!.run(inputTensor, outputTensor);

    // 5. Extract output vector and normalize using L2 norm
    final rawEmbedding = outputTensor[0];
    return _l2Normalize(rawEmbedding);
  }

  /// L2 normalization to project embeddings onto hypersphere unit vector
  List<double> _l2Normalize(List<double> embedding) {
    double sumOfSquares = 0.0;
    for (var val in embedding) {
      sumOfSquares += val * val;
    }
    final norm = math.sqrt(sumOfSquares);
    if (norm == 0) return embedding;
    return embedding.map((val) => val / norm).toList();
  }

  /// Calculates Euclidean distance between two face embeddings
  double calculateEuclideanDistance(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return double.infinity;

    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      final diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return math.sqrt(sum);
  }

  /// Calculates Cosine similarity between two face embeddings (range: -1 to 1)
  double calculateCosineSimilarity(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < e1.length; i++) {
      dotProduct += e1[i] * e2[i];
      normA += e1[i] * e1[i];
      normB += e2[i] * e2[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
