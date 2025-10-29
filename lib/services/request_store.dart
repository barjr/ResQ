import 'dart:async';
import 'package:resq/models/help_request.dart';
import 'package:uuid/uuid.dart';

class RequestStore {
  RequestStore._internal();

  static final RequestStore _instance = RequestStore._internal();
  static RequestStore get instance => _instance;

  final _requests = <HelpRequest>[];
  final _controller = StreamController<List<HelpRequest>>.broadcast();
  final _uuid = Uuid();

  Stream<List<HelpRequest>> get stream => _controller.stream;

  void addRequest({required String reporterName, required String description, String? location, Severity severity = Severity.critical,
  Source   source   = Source.sos,}) {
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
