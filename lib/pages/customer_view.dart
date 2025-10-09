import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/services/request_store.dart';

class CustomerViewPage extends StatelessWidget {
  const CustomerViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Customer View', style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xFFFC3B3C),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Request Assistance',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'If you need help, press the button below to send a request to nearby helpers.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      final noteCtrl = TextEditingController();
                      final locCtrl = TextEditingController();
                      return AlertDialog(
                        title: const Text('Quick Request'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: noteCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Short note (optional)',
                              ),
                            ),
                            TextField(
                              controller: locCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Location (optional)'
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              final user = FirebaseAuth.instance.currentUser;
                              final reporter = (user != null && user.email != null && user.email!.isNotEmpty)
                                  ? user.email!.split('@')[0]
                                  : 'Anonymous';
                              RequestStore.instance.addRequest(
                                reporterName: reporter,
                                description: noteCtrl.text.trim().isEmpty ? 'Help requested' : noteCtrl.text.trim(),
                                location: locCtrl.text.trim().isEmpty ? null : locCtrl.text.trim(),
                              );
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent')));
                            },
                            child: const Text('Send'),
                          ),
                        ],
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFC3B3C),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.call, color: Colors.white,),
                label: const Text('Request Help', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
