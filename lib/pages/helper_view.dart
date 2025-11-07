import 'dart:async';

import 'package:flutter/material.dart';
import 'package:resq/models/help_request.dart';
import 'package:resq/pages/home.dart';
import 'package:resq/services/request_store.dart';

class HelperViewPage extends StatefulWidget {
  const HelperViewPage({super.key});

  @override
  State<HelperViewPage> createState() => _HelperViewPageState();
}

class _HelperViewPageState extends State<HelperViewPage> {
  late final StreamSubscription<List<HelpRequest>> _sub;
  List<HelpRequest> _requests = [];

  @override
  void initState() {
    super.initState();
    _requests = RequestStore.instance.snapshot();
    _sub = RequestStore.instance.stream.listen((list) {
      setState(() => _requests = list);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _acceptRequest(int index) {
    final req = _requests[index];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Request'),
        content: Text('Accept request from ${req.reporterName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('You accepted ${req.reporterName}')),
              );
              RequestStore.instance.removeRequest(req.id);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Helper View', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFC3B3C),
        actions: [
          IconButton(
            tooltip: 'Back to Home',
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pending Requests',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _requests.isEmpty
                    ? const Center(child: Text('No pending requests'))
                    : ListView.separated(
                        itemCount: _requests.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final r = _requests[index];
                          return ListTile(
                            title: Text(r.reporterName),
                            subtitle: Text('${r.location ?? 'unknown location'} — ${r.description}'),
                            trailing: ElevatedButton(
                              onPressed: () => _acceptRequest(index),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFC3B3C),
                              ),
                              child: const Text('Accept', style: TextStyle(color: Colors.white)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
