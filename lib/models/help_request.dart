class HelpRequest {
  final String id;
  final String reporterName;
  final String description;
  final String? location;
  final DateTime createdAt;

  HelpRequest({
    required this.id,
    required this.reporterName,
    required this.description,
    this.location,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
