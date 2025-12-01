import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:resq/services/location_service.dart';
import 'package:resq/services/request_store.dart';
import 'package:resq/services/summarizer.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt; 

class SosReportPage extends StatefulWidget {
  const SosReportPage({super.key});

  @override
  State<SosReportPage> createState() => _SosReportPageState();
}

class _SosReportPageState extends State<SosReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _isSummarizing = false;
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _listening = false;
  double? _lat;
  double? _lng;
  @override
  void dispose() {
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(onError: (e) {
        // ignore: avoid_print
        print('Speech init error: $e');
      });
      setState(() {});
    } catch (e) {
      // ignore: avoid_print
      print('Error initializing speech: $e');
      _speechAvailable = false;
    }
  }

  void _toggleListening() async {
    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) return;
    }

    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(onResult: (result) {
      setState(() {
        // append recognized words to existing text
        final recognized = result.recognizedWords;
        if (_descCtrl.text.trim().isEmpty) {
          _descCtrl.text = recognized;
        } else {
          _descCtrl.text = '${_descCtrl.text} $recognized';
        }
        // move cursor to end
        _descCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _descCtrl.text.length));
      });
    });
  }

  Future<void> _summarize() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSummarizing = true);
    final summarizer = MockSummarizer();
    final summary = await summarizer.summarize(
      description: _descCtrl.text.trim(),
      location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSummarizing = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('AI Summary'),
        content: Text(summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {  // Add async here
              Navigator.of(context).pop();
              


              try {
                final currentUser = FirebaseAuth.instance.currentUser;
final reporterUid = currentUser?.uid;
final reporterName = (() {
  if (currentUser == null) return 'Anonymous';
  if (currentUser.displayName != null &&
      currentUser.displayName!.trim().isNotEmpty) {
    return currentUser.displayName!.trim();
  }
  final email = currentUser.email;
  if (email != null && email.contains('@')) {
    return email.split('@').first;
  }
  return 'User';
})();
                // Save to Firestore - this triggers the Cloud Function
await FirebaseFirestore.instance
    .collection('emergency_requests')
    .add({
  'reporterName': reporterName,
  'reporterUid': reporterUid, // may be null for anonymous
  'description': _descCtrl.text.trim(),
  'location': _locationCtrl.text.trim().isEmpty 
      ? null 
      : _locationCtrl.text.trim(),
  'timestamp': FieldValue.serverTimestamp(),
  'status': 'pending',

  // precise coordinates (if we have them)
  'lat': _lat,
  'lng': _lng,
});
                
                // Still add to in-memory store for local use
                RequestStore.instance.addRequest(
  reporterName: reporterName,
  description: _descCtrl.text.trim(),
  location: _locationCtrl.text.trim().isEmpty 
      ? null 
      : _locationCtrl.text.trim(),
);
                
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Emergency alert sent to helpers!')),
                );
                Navigator.of(context).pop();
              } catch (e) {
                print('Failed to submit request: $e');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Submit'),
          ),
          //),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Describe your emergency', style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xFFFC3B3C),
        actions: [
          IconButton(
            tooltip: 'Use voice input',
            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
            onPressed: _toggleListening,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tell us what happened in a few sentences. Be specific about injuries, hazards, number of people involved, and any visible danger.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _descCtrl,
                        maxLines: null,
                        minLines: 6,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Describe the situation',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe the situation' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          iconSize: 36,
                          color: _listening ? Colors.red : null,
                          icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                          onPressed: _toggleListening,
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            _speechAvailable ? (_listening ? 'Listening' : 'Ready') : 'Unavailable',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: _speechAvailable ? Colors.grey : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: TextFormField(
        controller: _locationCtrl,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Location (optional)',
          hintText: 'e.g., near 5th Ave & Pine St',
        ),
      ),
    ),
    const SizedBox(width: 8),
    IconButton(
      tooltip: 'Use my current location',
      icon: const Icon(Icons.my_location),
      onPressed: () async {
        final pos = await LocationService.getCurrentPosition();
        if (!mounted) return;
        if (pos == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get location. Check permissions.'),
            ),
          );
          return;
        }
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          // Put something human-readable into the text field
          _locationCtrl.text = 'Lat: ${pos.latitude.toStringAsFixed(5)}, '
              'Lng: ${pos.longitude.toStringAsFixed(5)}';
        });
      },
    ),
  ],
),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSummarizing ? null : _summarize,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFC3B3C)),
                    child: _isSummarizing
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('Submit', style: TextStyle(color: Colors.white),),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.black),),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
