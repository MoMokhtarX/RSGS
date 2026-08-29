class CustomerFollowUpModel {
  final int id;
  final int customerId;
  final int userId;
  final String? userName;
  final String type;
  final DateTime scheduledAt;
  final DateTime? completedAt;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const CustomerFollowUpModel({required this.id, required this.customerId, required this.userId, this.userName, required this.type, required this.scheduledAt, this.completedAt, required this.status, this.notes, required this.createdAt});

  factory CustomerFollowUpModel.fromMap(Map<String, dynamic> m) => CustomerFollowUpModel(
    id: (m['id'] as num?)?.toInt() ?? 0, customerId: (m['customerId'] as num?)?.toInt() ?? 0,
    userId: (m['userId'] as num?)?.toInt() ?? 0, userName: m['userName']?.toString(), type: m['type']?.toString() ?? 'Call',
    scheduledAt: DateTime.tryParse(m['scheduledAt']?.toString() ?? '') ?? DateTime.now(),
    completedAt: DateTime.tryParse(m['completedAt']?.toString() ?? ''), status: m['status']?.toString() ?? 'Pending',
    notes: m['notes']?.toString(), createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );
}

class CustomerInteractionModel {
  final int id;
  final int customerId;
  final int userId;
  final String? userName;
  final String type;
  final String? subject;
  final String details;
  final DateTime occurredAt;
  final DateTime createdAt;

  const CustomerInteractionModel({required this.id, required this.customerId, required this.userId, this.userName, required this.type, this.subject, required this.details, required this.occurredAt, required this.createdAt});

  factory CustomerInteractionModel.fromMap(Map<String, dynamic> m) => CustomerInteractionModel(
    id: (m['id'] as num?)?.toInt() ?? 0, customerId: (m['customerId'] as num?)?.toInt() ?? 0,
    userId: (m['userId'] as num?)?.toInt() ?? 0, userName: m['userName']?.toString(), type: m['type']?.toString() ?? 'Note',
    subject: m['subject']?.toString(), details: m['details']?.toString() ?? '',
    occurredAt: DateTime.tryParse(m['occurredAt']?.toString() ?? '') ?? DateTime.now(),
    createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );
}
