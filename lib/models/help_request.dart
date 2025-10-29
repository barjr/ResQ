enum Severity { minor, urgent, critical }
enum Source   { sos, report }

class HelpRequest {
  final String id;
  final String reporterName;
  final String description;
  final String? location;
  final DateTime createdAt;
  final Severity severity;
  final Source source;

  HelpRequest({
    required this.id,
    required this.reporterName,
    required this.description,
    this.location,
    this.severity = Severity.critical,
    this.source = Source.sos,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
