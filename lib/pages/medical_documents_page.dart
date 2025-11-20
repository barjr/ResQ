import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class MedicalDocumentsPage extends StatefulWidget {
  const MedicalDocumentsPage({super.key});

  @override
  State<MedicalDocumentsPage> createState() => _MedicalDocumentsPageState();
}

class _MedicalDocumentsPageState extends State<MedicalDocumentsPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;
  String? _statusMessage;

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'jpg',
          'jpeg',
          'png',
        ],
        withData: true, // we will upload from bytes
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files;
          _statusMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to pick files: $e';
      });
    }
  }

  Future<void> _uploadFiles() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _statusMessage = 'You must be logged in to upload documents.';
      });
      return;
    }

    if (_selectedFiles.isEmpty) {
      setState(() {
        _statusMessage = 'Please select at least one file.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _statusMessage = null;
    });

    final uid = user.uid;
    int successCount = 0;
    int failCount = 0;

    for (final file in _selectedFiles) {
      try {
        final bytes = file.bytes;
        if (bytes == null) {
          failCount++;
          continue;
        }

        // Create a Firestore doc ID first so we can link storage + metadata
        final docRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('medicalDocuments')
            .doc();

        final storagePath = 'medical_files/$uid/${docRef.id}_${file.name}';
        final storageRef = _storage.ref().child(storagePath);

        final contentType = _guessContentType(file.extension);

        final uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );

        await uploadTask;

        final metadata = await storageRef.getMetadata();

        await docRef.set({
          'fileName': file.name,
          'storagePath': storagePath,
          'uploadedAt': FieldValue.serverTimestamp(),
          'fileType': metadata.contentType ?? contentType,
          'sizeBytes': metadata.size,
          'helperCanView': false, // for future emergency feature
        });

        successCount++;
      } catch (e) {
        failCount++;
        debugPrint('Upload failed for ${file.name}: $e');
      }
    }

    setState(() {
      _isUploading = false;
      _selectedFiles = [];
      _statusMessage =
          'Upload complete. Success: $successCount, Failed: $failCount';
    });

    if (mounted && successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded $successCount document(s).')),
      );
    }
  }

  String _guessContentType(String? ext) {
    final e = (ext ?? '').toLowerCase();
    switch (e) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Medical Documents',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFC3B3C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Upload important medical documents (PDFs, doctor notes, etc.) '
                'so helpers can view them during an emergency in a future update.',
                style: TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 16),

              // Pick files button
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickFiles,
                icon: const Icon(Icons.attach_file),
                label: const Text('Select files'),
              ),

              const SizedBox(height: 12),

              // Selected file list
              if (_selectedFiles.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _selectedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _selectedFiles[index];
                      return ListTile(
                        leading: const Icon(Icons.description),
                        title: Text(file.name),
                        subtitle: Text(
                          '${(file.size / 1024).toStringAsFixed(1)} KB',
                        ),
                      );
                    },
                  ),
                )
              else
                const Expanded(
                  child: Center(
                    child: Text(
                      'No files selected yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              if (_statusMessage != null)
                Text(
                  _statusMessage!,
                  style: const TextStyle(color: Colors.black87),
                ),

              const SizedBox(height: 8),

              // Upload button
              FilledButton.icon(
                onPressed: _isUploading ? null : _uploadFiles,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isUploading ? 'Uploading...' : 'Upload'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
