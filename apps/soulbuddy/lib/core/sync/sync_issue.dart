class SyncIssue {
  const SyncIssue({
    required this.recordType,
    required this.recordId,
    required this.code,
    required this.message,
    required this.createdAt,
  });

  final String recordType;
  final String recordId;
  final String code;
  final String message;
  final DateTime createdAt;
}
