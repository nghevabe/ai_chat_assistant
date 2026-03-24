import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Upload Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Firebase Upload Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ImagePicker _imagePicker = ImagePicker();

  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://ai-assistant-service-d86f3.firebasestorage.app',
  );

  bool _isFirebaseReady = false;
  bool _isUploading = false;
  String? _uploadedImageUrl;
  String? _selectedImagePath;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _checkFirebase();
  }

  Future<void> _checkFirebase() async {
    try {
      setState(() {
        _isFirebaseReady = true;
      });
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'app_image_storage/$timestamp.jpg';

      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
        _selectedImagePath = pickedFile.path;
        _uploadedImageUrl = null;
      });

      final ref = _storage.ref().child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );

      final uploadTask = ref.putFile(file, metadata);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final totalBytes = snapshot.totalBytes;
        final transferredBytes = snapshot.bytesTransferred;

        if (totalBytes > 0) {
          setState(() {
            _uploadProgress = transferredBytes / totalBytes;
          });
        }
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _uploadedImageUrl = downloadUrl;
        _isUploading = false;
        _uploadProgress = 1;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload ảnh thành công')),
      );
    } on FirebaseException catch (e) {
      setState(() {
        _isUploading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi Firebase: ${e.code} - ${e.message ?? ""}'),
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload thất bại: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = (_uploadProgress * 100).toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  _isFirebaseReady
                      ? '🔥 Firebase connected successfully'
                      : '⏳ Connecting Firebase...',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _pickAndUploadImage,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _isUploading ? 'Đang upload...' : 'Chọn ảnh và upload',
                  ),
                ),
                const SizedBox(height: 16),
                if (_isUploading) ...[
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('Tiến độ upload: $progressPercent%'),
                  const SizedBox(height: 16),
                ],
                if (_selectedImagePath != null) ...[
                  const Text(
                    'Ảnh đã chọn:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Image.file(
                    File(_selectedImagePath!),
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 16),
                ],
                if (_uploadedImageUrl != null) ...[
                  const Text(
                    'Download URL:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _uploadedImageUrl!,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}