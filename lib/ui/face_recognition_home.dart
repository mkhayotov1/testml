/*
 * File: lib/ui/face_recognition_home.dart
 *
 * Purpose:
 * Main user interface providing dual tabs for (1) Face Comparison between two photos,
 * and (2) Face Database registration and identification. Utilizes BLoC pattern with
 * [BlocProvider], [BlocConsumer], and [BlocListener].
 *
 * Connected Files:
 * - Created by [MyApp] in `lib/main.dart`.
 * - Uses [FaceRecognitionBloc] in `lib/bloc/face_recognition_bloc.dart`.
 * - Dispatches events from `lib/bloc/face_recognition_event.dart`.
 * - Reads state from `lib/bloc/face_recognition_state.dart`.
 * - Instantiates services from `lib/services/face_detector_service.dart` and `lib/services/face_recognizer_service.dart`.
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../bloc/face_recognition_bloc.dart';
import '../bloc/face_recognition_event.dart';
import '../bloc/face_recognition_state.dart';
import '../services/face_detector_service.dart';
import '../services/face_recognizer_service.dart';

class FaceRecognitionHomeWrapper extends StatelessWidget {
  const FaceRecognitionHomeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FaceRecognitionBloc(
        detectorService: FaceDetectorService(),
        recognizerService: FaceRecognizerService(),
      )..add(const InitializeModelEvent()),
      child: const FaceRecognitionHome(),
    );
  }
}

class FaceRecognitionHome extends StatefulWidget {
  const FaceRecognitionHome({super.key});

  @override
  State<FaceRecognitionHome> createState() => _FaceRecognitionHomeState();
}

class _FaceRecognitionHomeState extends State<FaceRecognitionHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _promptRegisterFace(BuildContext context, ImageSource source) async {
    final nameController = TextEditingController();
    final nameSubmitted = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register Face'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Person Name',
            hintText: 'e.g., Alice, Bob',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (nameSubmitted == null || nameSubmitted.isEmpty) return;
    if (!context.mounted) return;

    context.read<FaceRecognitionBloc>().add(
          RegisterFaceEvent(
            name: nameSubmitted,
            source: source,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FaceRecognitionBloc, FaceRecognitionState>(
      listenWhen: (previous, current) =>
          current.toastMessage != null &&
          current.toastMessage != previous.toastMessage,
      listener: (context, state) {
        if (state.toastMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.toastMessage!),
              backgroundColor: state.toastMessage!.contains('Error') ||
                      state.toastMessage!.contains('No face') ||
                      state.toastMessage!.contains('No faces') ||
                      state.toastMessage!.contains('Failed')
                  ? Colors.red
                  : (state.toastMessage!.contains('Please')
                      ? Colors.orange
                      : Colors.green),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Face Recognition (TFLite BLoC)'),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.compare_arrows), text: 'Compare 2 Faces'),
              Tab(icon: Icon(Icons.face), text: 'Face Database'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Model Status Banner
            BlocBuilder<FaceRecognitionBloc, FaceRecognitionState>(
              buildWhen: (p, c) =>
                  p.isModelLoading != c.isModelLoading ||
                  p.isModelLoaded != c.isModelLoaded ||
                  p.statusMessage != c.statusMessage,
              builder: (context, state) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: state.isModelLoading
                      ? Colors.amber.shade100
                      : (state.isModelLoaded
                          ? Colors.green.shade50
                          : Colors.red.shade100),
                  child: Row(
                    children: [
                      Icon(
                        state.isModelLoading
                            ? Icons.hourglass_top
                            : (state.isModelLoaded
                                ? Icons.check_circle
                                : Icons.error),
                        color: state.isModelLoading
                            ? Colors.amber.shade900
                            : (state.isModelLoaded
                                ? Colors.green.shade800
                                : Colors.red.shade900),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.statusMessage,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: state.isModelLoading
                                ? Colors.amber.shade900
                                : (state.isModelLoaded
                                    ? Colors.green.shade900
                                    : Colors.red.shade900),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCompareTab(context),
                  _buildDatabaseTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tab 1: Compare Two Photos
  Widget _buildCompareTab(BuildContext context) {
    return BlocBuilder<FaceRecognitionBloc, FaceRecognitionState>(
      builder: (context, state) {
        final bool isMatched = state.euclideanDistance != null &&
            (state.euclideanDistance! < 1.0 ||
                (state.similarityScore ?? 0) > 0.65);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Quick Sample Test Toolbar
              Card(
                color: Colors.deepPurple.shade50,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '⚡ Quick Sample Test',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context
                                  .read<FaceRecognitionBloc>()
                                  .add(const LoadSampleCompareImagesEvent(
                                      samePerson: true)),
                              icon: const Icon(Icons.people, size: 18),
                              label: const Text('Same Person',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context
                                  .read<FaceRecognitionBloc>()
                                  .add(const LoadSampleCompareImagesEvent(
                                      samePerson: false)),
                              icon: const Icon(Icons.people_outline, size: 18),
                              label: const Text('Different',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildImagePickerCard(
                      context: context,
                      title: 'Person 1',
                      file: state.image1,
                      croppedImage: state.croppedFace1,
                      onGallery: () => context
                          .read<FaceRecognitionBloc>()
                          .add(const PickCompareImageEvent(
                            targetIndex: 1,
                            source: ImageSource.gallery,
                          )),
                      onCamera: () => context
                          .read<FaceRecognitionBloc>()
                          .add(const PickCompareImageEvent(
                            targetIndex: 1,
                            source: ImageSource.camera,
                          )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildImagePickerCard(
                      context: context,
                      title: 'Person 2',
                      file: state.image2,
                      croppedImage: state.croppedFace2,
                      onGallery: () => context
                          .read<FaceRecognitionBloc>()
                          .add(const PickCompareImageEvent(
                            targetIndex: 2,
                            source: ImageSource.gallery,
                          )),
                      onCamera: () => context
                          .read<FaceRecognitionBloc>()
                          .add(const PickCompareImageEvent(
                            targetIndex: 2,
                            source: ImageSource.camera,
                          )),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (state.isComparing)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Detecting faces & extracting embeddings...'),
                    ],
                  ),
                ),
              if (state.euclideanDistance != null && !state.isComparing) ...[
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color:
                      isMatched ? Colors.green.shade50 : Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          isMatched ? Icons.verified : Icons.dangerous,
                          size: 48,
                          color: isMatched ? Colors.green : Colors.red,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isMatched
                              ? 'MATCH: SAME PERSON'
                              : 'NO MATCH: DIFFERENT PERSONS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isMatched
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMetricChip(
                              'Euclidean Distance',
                              state.euclideanDistance!.toStringAsFixed(4),
                              '< 1.0 is match',
                            ),
                            _buildMetricChip(
                              'Similarity Score',
                              '${((state.similarityScore ?? 0) * 100).toStringAsFixed(1)}%',
                              '> 65% is match',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricChip(String label, String value, String hint) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildImagePickerCard({
    required BuildContext context,
    required String title,
    required File? file,
    required img.Image? croppedImage,
    required VoidCallback onGallery,
    required VoidCallback onCamera,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: file != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(file, fit: BoxFit.cover),
                    )
                  : const Center(
                      child:
                          Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                    ),
            ),
            if (croppedImage != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Cropped Face: ', style: TextStyle(fontSize: 10)),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Image.memory(
                      img.encodePng(croppedImage),
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: IconButton.outlined(
                    onPressed: onGallery,
                    icon: const Icon(Icons.photo_library),
                    tooltip: 'Pick Gallery',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: IconButton.outlined(
                    onPressed: onCamera,
                    icon: const Icon(Icons.camera_alt),
                    tooltip: 'Take Photo',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Tab 2: Register & Recognize
  Widget _buildDatabaseTab(BuildContext context) {
    return BlocBuilder<FaceRecognitionBloc, FaceRecognitionState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preload Sample Faces Button
              OutlinedButton.icon(
                onPressed: () => context
                    .read<FaceRecognitionBloc>()
                    .add(const RegisterSampleFacesEvent()),
                icon: const Icon(Icons.group_add),
                label: const Text('Preload Sample Faces (Alex & Sophia)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: state.isRegistering
                          ? null
                          : () =>
                              _promptRegisterFace(context, ImageSource.gallery),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Register Face'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: state.isRecognizing
                          ? null
                          : () => context
                              .read<FaceRecognitionBloc>()
                              .add(const RecognizeFaceEvent(
                                source: ImageSource.gallery,
                              )),
                      icon: const Icon(Icons.search),
                      label: const Text('Recognize Face'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (state.isRegistering || state.isRecognizing)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(
                          state.isRegistering
                              ? 'Registering face embedding...'
                              : 'Recognizing face against database...',
                        ),
                      ],
                    ),
                  ),
                ),
              if (state.recognitionResult != null &&
                  !state.isRecognizing) ...[
                Card(
                  color: Colors.deepPurple.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          state.recognitionResult == 'Unknown Face'
                              ? Icons.person_off
                              : Icons.account_circle,
                          size: 44,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recognition Result:',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                state.recognitionResult!,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (state.recognitionConfidence != null)
                                Text(
                                  'Confidence: ${(state.recognitionConfidence! * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Registered Face Database',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (state.registeredFaces.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'No faces registered yet.\nTap "Register Face" to add names and face embeddings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.registeredFaces.length,
                  itemBuilder: (context, index) {
                    final item = state.registeredFaces[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: item.imagePath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(item.imagePath!),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Embedding Vector: ${item.embedding.length} values',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            context.read<FaceRecognitionBloc>().add(
                                  DeleteRegisteredFaceEvent(id: item.id),
                                );
                          },
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
