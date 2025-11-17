import 'dart:async';
import 'package:resq/models/help_request.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;

class RequestStore {
  RequestStore._internal();

  static final RequestStore _instance = RequestStore._internal();
  static RequestStore get instance => _instance;

  final _requests = <HelpRequest>[];
  final _controller = StreamController<List<HelpRequest>>.broadcast();
  final _uuid = Uuid();

  Stream<List<HelpRequest>> get stream => _controller.stream;

  // Optional Firestore sync subscription. Call startFirestoreSync() once
  // (for example at app startup) to keep the in-memory store in sync with
  // the Firestore 'emergency_requests' collection. This allows helpers
  // and admins on other devices to see requests in real-time.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _fsSub;

  void startFirestoreSync({String collection = 'emergency_requests'}) {
    // avoid starting multiple listeners
    if (_fsSub != null) return;
    // Query: only filter by pending status server-side to avoid requiring a
    // composite index (which can cause the listener to fail at runtime).
    // We sort the results client-side by timestamp (descending) so helpers
    // see the most recent requests first.
    _fsSub = FirebaseFirestore.instance
        .collection(collection)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
          try {
            final docs = snap.docs;
            // map docs into HelpRequest list
            final list = docs.map((d) {
              final data = d.data();
              final id = d.id;
              final reporterName =
                  (data['reporterName'] as String?) ?? 'Anonymous';
              final description = (data['description'] as String?) ?? '';
              final location = (data['location'] as String?);
              final ts = data['timestamp'];
              DateTime created;
              if (ts is Timestamp) {
                created = ts.toDate();
              } else {
                created = DateTime.now();
              }
              // severity stored as string? default to critical
              final sevRaw = data['severity'] as String?;
              Severity sev = Severity.critical;
              if (sevRaw != null) {
                if (sevRaw.toLowerCase() == 'minor') sev = Severity.minor;
                if (sevRaw.toLowerCase() == 'urgent') sev = Severity.urgent;
                if (sevRaw.toLowerCase() == 'critical') sev = Severity.critical;
              }
              // source
              final srcRaw = data['source'] as String?;
              Source src = Source.sos;
              if (srcRaw != null) {
                if (srcRaw.toLowerCase() == 'report') src = Source.report;
                if (srcRaw.toLowerCase() == 'sos') src = Source.sos;
              }

              return HelpRequest(
                id: id,
                reporterName: reporterName,
                description: description,
                location: location,
                severity: sev,
                source: src,
                createdAt: created,
              );
            }).toList();

            // Sort client-side by createdAt descending so newest appear first.
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            // replace in-memory requests with snapshot from Firestore
            _requests
              ..clear()
              ..addAll(list);

            _controller.add(List.unmodifiable(_requests));
          } catch (e) {
            // ignore: avoid_print
            print('RequestStore Firestore sync error: $e');
          }
        });
  }

  void stopFirestoreSync() {
    _fsSub?.cancel();
    _fsSub = null;
  }

  void addRequest({
    required String reporterName,
    required String description,
    String? location,
    Severity severity = Severity.critical,
    Source source = Source.sos,
  }) {
    final req = HelpRequest(
      id: _uuid.v4(),
      reporterName: reporterName,
      description: description,
      location: location,
      severity: severity,
      source: source,
      createdAt: DateTime.now(),
    );
    _requests.insert(0, req);
    _controller.add(List.unmodifiable(_requests));
  }

  void removeRequest(String id) {
    _requests.removeWhere((r) => r.id == id);
    _controller.add(List.unmodifiable(_requests));
  }

  List<HelpRequest> snapshot() => List.unmodifiable(_requests);
}
