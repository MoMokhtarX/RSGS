class UserModel {
  UserModel({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.fullName,
    required this.email,
    required this.role,
    this.isActive = true,
    this.createdAt,
  });

  final int id;
  final String username;
  final String passwordHash;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  factory UserModel.fromMap(Map<String, Object?> map) => UserModel(
        id: _toInt(map['id']) ?? 0,
        username: (map['username'] ?? '').toString(),
        passwordHash:
            (map['passwordHash'] ?? map['password_hash'] ?? '').toString(),
        fullName:
            (map['fullName'] ?? map['full_name'] ?? '').toString(),
        email: (map['email'] ?? '').toString(),
        role: _roleText(map['role']),
        isActive: _toBool(
          map['isActive'] ?? map['is_active'],
          defaultValue: true,
        ),
        createdAt: _dateValue(map['createdAt'] ?? map['created_at']),
      );
}

class CustomerModel {
  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.phone2,
    this.email,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.governorate,
    this.city,
    this.channel,
    this.inquiryDate,
    this.followUpStatus,
    this.assignedUserId,
    this.firstCallNotes,
    this.firstActionDate,
    this.secondCallNotes,
    this.secondActionDate,
    this.thirdCallNotes,
    this.thirdActionDate,
    this.fourthCallNotes,
    this.fourthActionDate,
  });

  final int id;
  final String name;
  final String phone;
  final String? phone2;
  final String? email;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? governorate;
  final String? city;

  final String? channel;
  final DateTime? inquiryDate;
  final String? followUpStatus;
  final int? assignedUserId;
  final String? firstCallNotes;
  final DateTime? firstActionDate;
  final String? secondCallNotes;
  final DateTime? secondActionDate;
  final String? thirdCallNotes;
  final DateTime? thirdActionDate;
  final String? fourthCallNotes;
  final DateTime? fourthActionDate;

  CustomerModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? phone2,
    String? email,
    String? notes,
    DateTime? updatedAt,
    String? governorate,
    String? city,
    String? channel,
    DateTime? inquiryDate,
    String? followUpStatus,
    int? assignedUserId,
    String? firstCallNotes,
    DateTime? firstActionDate,
    String? secondCallNotes,
    DateTime? secondActionDate,
    String? thirdCallNotes,
    DateTime? thirdActionDate,
    String? fourthCallNotes,
    DateTime? fourthActionDate,
  }) =>
      CustomerModel(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        phone2: phone2 ?? this.phone2,
        email: email ?? this.email,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        governorate: governorate ?? this.governorate,
        city: city ?? this.city,
        channel: channel ?? this.channel,
        inquiryDate: inquiryDate ?? this.inquiryDate,
        followUpStatus: followUpStatus ?? this.followUpStatus,
        assignedUserId: assignedUserId ?? this.assignedUserId,
        firstCallNotes: firstCallNotes ?? this.firstCallNotes,
        firstActionDate: firstActionDate ?? this.firstActionDate,
        secondCallNotes: secondCallNotes ?? this.secondCallNotes,
        secondActionDate: secondActionDate ?? this.secondActionDate,
        thirdCallNotes: thirdCallNotes ?? this.thirdCallNotes,
        thirdActionDate: thirdActionDate ?? this.thirdActionDate,
        fourthCallNotes: fourthCallNotes ?? this.fourthCallNotes,
        fourthActionDate: fourthActionDate ?? this.fourthActionDate,
      );

  factory CustomerModel.fromMap(Map<String, Object?> map) => CustomerModel(
        id: _toInt(map['id']) ?? 0,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        phone2: map['phone2'] as String?,
        email: map['email'] as String?,
        notes: map['notes'] as String?,
        createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
        governorate: map['governorate'] as String?,
        city: map['city'] as String?,
        channel: map['channel'] as String?,
        inquiryDate: map['inquiry_date'] != null ? DateTime.parse(map['inquiry_date'] as String) : null,
        followUpStatus: map['follow_up_status'] as String?,
        assignedUserId: _toInt(map['assigned_user_id']),
        firstCallNotes: map['first_call_notes'] as String?,
        firstActionDate: map['first_action_date'] != null ? DateTime.parse(map['first_action_date'] as String) : null,
        secondCallNotes: map['second_call_notes'] as String?,
        secondActionDate: map['second_action_date'] != null ? DateTime.parse(map['second_action_date'] as String) : null,
        thirdCallNotes: map['third_call_notes'] as String?,
        thirdActionDate: map['third_action_date'] != null ? DateTime.parse(map['third_action_date'] as String) : null,
        fourthCallNotes: map['fourth_call_notes'] as String?,
        fourthActionDate: map['fourth_action_date'] != null ? DateTime.parse(map['fourth_action_date'] as String) : null,
      );

  Map<String, Object?> toMap() => {
        'name': name,
        'phone': phone,
        'phone2': phone2,
        'email': email,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
        'governorate': governorate,
        'city': city,
        'channel': channel,
        'inquiry_date': inquiryDate?.toIso8601String(),
        'follow_up_status': followUpStatus,
        'assigned_user_id': assignedUserId,
        'first_call_notes': firstCallNotes,
        'first_action_date': firstActionDate?.toIso8601String(),
        'second_call_notes': secondCallNotes,
        'second_action_date': secondActionDate?.toIso8601String(),
        'third_call_notes': thirdCallNotes,
        'third_action_date': thirdActionDate?.toIso8601String(),
        'fourth_call_notes': fourthCallNotes,
        'fourth_action_date': fourthActionDate?.toIso8601String(),
      };
}

class ProjectModel {
  ProjectModel({
    required this.id,
    required this.projectNumber,
    required this.name,
    required this.customerId,
    this.engineerId,
    this.status = 'Draft',
    this.createdDate,
    this.installationDate,
    this.notes,
    this.totalValue = 0,
    this.totalKw = 0,
    this.address,
    this.governorate,
    this.city,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String projectNumber;
  final String name;
  final int customerId;
  final int? engineerId;
  final String status;
  final DateTime? createdDate;
  final DateTime? installationDate;
  final String? notes;
  final double totalValue;
  final double totalKw;
  final String? address;
  final String? governorate;
  final String? city;
  final double? latitude;
  final double? longitude;

  ProjectModel copyWith({
    int? id,
    String? projectNumber,
    String? name,
    int? customerId,
    int? engineerId,
    String? status,
    DateTime? createdDate,
    DateTime? installationDate,
    String? notes,
    double? totalValue,
    double? totalKw,
    String? address,
    String? governorate,
    String? city,
    double? latitude,
    double? longitude,
  }) =>
      ProjectModel(
        id: id ?? this.id,
        projectNumber: projectNumber ?? this.projectNumber,
        name: name ?? this.name,
        customerId: customerId ?? this.customerId,
        engineerId: engineerId ?? this.engineerId,
        status: status ?? this.status,
        createdDate: createdDate ?? this.createdDate,
        installationDate: installationDate ?? this.installationDate,
        notes: notes ?? this.notes,
        totalValue: totalValue ?? this.totalValue,
        totalKw: totalKw ?? this.totalKw,
        address: address ?? this.address,
        governorate: governorate ?? this.governorate,
        city: city ?? this.city,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );

  static dynamic _value(Map<String, Object?> map, String camel, String snake) =>
      map.containsKey(camel) ? map[camel] : map[snake];

  static String _status(dynamic value) {
    if (value is num) {
      return switch (value.toInt()) {
        1 => 'Draft',
        2 => 'Pending',
        3 => 'Approved',
        4 => 'In Progress',
        5 => 'Completed',
        6 => 'Cancelled',
        _ => 'Draft',
      };
    }
    final text = value?.toString() ?? 'Draft';
    final normalized = text.replaceAll('_', ' ').trim().toLowerCase();
    return switch (normalized) {
      'inprogress' || 'in progress' => 'In Progress',
      'pending' => 'Pending',
      'approved' => 'Approved',
      'completed' => 'Completed',
      'cancelled' || 'canceled' => 'Cancelled',
      _ => 'Draft',
    };
  }

  static DateTime? _date(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  factory ProjectModel.fromMap(Map<String, Object?> map) => ProjectModel(
        id: _toInt(map['id']) ?? 0,
        projectNumber: (_value(map, 'projectNumber', 'project_number') as String?) ?? '',
        name: map['name'] as String? ?? '',
        customerId: _toInt(_value(map, 'customerId', 'customer_id')) ?? 0,
        engineerId: _toInt(_value(map, 'engineerId', 'engineer_id')),
        status: _status(map['status']),
        createdDate: _date(_value(map, 'createdDate', 'created_date')),
        installationDate: _date(_value(map, 'installationDate', 'installation_date')),
        notes: map['notes'] as String?,
        totalValue: _toDouble(map['totalValue'] ?? map['total_value']) ?? 0,
        totalKw: _toDouble(map['totalKW'] ?? map['totalKw'] ?? map['total_kw']) ?? 0,
        address: map['address'] as String?,
        governorate: map['governorate'] as String?,
        city: map['city'] as String?,
        latitude: _toDouble(map['latitude']),
        longitude: _toDouble(map['longitude']),
      );

  Map<String, dynamic> toApiCreateJson() => {
        'projectNumber': projectNumber,
        'name': name,
        'customerId': customerId,
        'engineerId': engineerId,
        'status': _statusToApi(status),
        'installationDate': installationDate?.toIso8601String(),
        'notes': notes,
        'totalValue': totalValue,
        'totalKW': totalKw,
        'address': address,
        'governorate': governorate,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
      };

  Map<String, dynamic> toApiUpdateJson() => toApiCreateJson();

  static int _statusToApi(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending': return 2;
      case 'approved': return 3;
      case 'in progress':
      case 'inprogress': return 4;
      case 'completed': return 5;
      case 'cancelled':
      case 'canceled': return 6;
      default: return 1;
    }
  }

  Map<String, Object?> toMap() => {
        'project_number': projectNumber,
        'name': name,
        'customer_id': customerId,
        'engineer_id': engineerId,
        'status': status,
        'installation_date': installationDate?.toIso8601String(),
        'notes': notes,
        'total_value': totalValue,
        'total_kw': totalKw,
        'address': address,
        'governorate': governorate,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
      };
}

class NotificationModel {
  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'info',
    this.isRead = false,
    this.createdAt,
    this.scheduledFor,
  });

  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? scheduledFor;

  NotificationModel copyWith({
    int? id,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    DateTime? scheduledFor,
  }) =>
      NotificationModel(
        id: id ?? this.id,
        title: title ?? this.title,
        message: message ?? this.message,
        type: type ?? this.type,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt ?? this.createdAt,
        scheduledFor: scheduledFor ?? this.scheduledFor,
      );

  factory NotificationModel.fromMap(Map<String, Object?> map) =>
      NotificationModel(
        id: _toInt(map['id']) ?? 0,
        title: (map['title'] ?? '').toString(),
        message: (map['message'] ?? '').toString(),
        type: _notificationTypeText(map['type']),
        isRead: _toBool(
          map['isRead'] ?? map['is_read'],
          defaultValue: false,
        ),
        createdAt: _dateValue(map['createdAt'] ?? map['created_at']),
        scheduledFor: _dateValue(
          map['scheduledFor'] ?? map['scheduled_for'],
        ),
      );

  Map<String, dynamic> toApiCreateJson() => {
        'title': title,
        'message': message,
        'type': _notificationTypeValue(type),
        'scheduledFor': scheduledFor?.toUtc().toIso8601String(),
      };
}

String _notificationTypeText(dynamic value) {
  if (value is num) {
    switch (value.toInt()) {
      case 1:
        return 'info';
      case 2:
        return 'success';
      case 3:
        return 'warning';
      case 4:
        return 'error';
      case 5:
        return 'follow_up';
      case 6:
        return 'reminder';
      default:
        return 'other';
    }
  }
  return value?.toString().toLowerCase() ?? 'info';
}

int _notificationTypeValue(String type) {
  switch (type.trim().toLowerCase()) {
    case 'info':
      return 1;
    case 'success':
      return 2;
    case 'warning':
      return 3;
    case 'error':
      return 4;
    case 'followup':
    case 'follow_up':
      return 5;
    case 'reminder':
      return 6;
    default:
      return 99;
  }
}

class CalendarEventModel {
  CalendarEventModel({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.type = 'task',
    this.isCompleted = false,
    this.referenceId,
    this.referenceType,
  });

  final int id;
  final String title;
  final String? description;
  final DateTime date;
  final String type;
  final bool isCompleted;
  final int? referenceId;
  final String? referenceType;

  factory CalendarEventModel.fromMap(Map<String, Object?> map) =>
      CalendarEventModel(
        id: _toInt(map['id']) ?? 0,
        title: (map['title'] ?? '').toString(),
        description: map['description']?.toString(),
        date: _dateValue(map['eventDate'] ?? map['date']) ?? DateTime.now(),
        type: _calendarTypeText(map['type']),
        isCompleted: _toBool(
          map['isCompleted'] ?? map['is_completed'],
          defaultValue: false,
        ),
        referenceId:
            _toInt(map['referenceId'] ?? map['reference_id']),
        referenceType:
            (map['referenceType'] ?? map['reference_type'])?.toString(),
      );

  Map<String, Object?> toMap() => {
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'type': type,
        'is_completed': isCompleted ? 1 : 0,
        'reference_id': referenceId,
        'reference_type': referenceType,
      };

  Map<String, dynamic> toApiJson() => {
        'title': title,
        'description': description,
        'eventDate': date.toUtc().toIso8601String(),
        'type': _calendarTypeValue(type),
        'referenceId': referenceId,
        'referenceType': referenceType,
        'isCompleted': isCompleted,
      };
}

String _calendarTypeText(dynamic value) {
  if (value is num) {
    switch (value.toInt()) {
      case 1:
        return 'task';
      case 2:
        return 'follow_up';
      case 3:
        return 'meeting';
      case 4:
        return 'installation';
      case 5:
        return 'maintenance';
      case 6:
        return 'reminder';
      default:
        return 'other';
    }
  }
  return value?.toString().toLowerCase() ?? 'task';
}

int _calendarTypeValue(String type) {
  switch (type.trim().toLowerCase()) {
    case 'task':
      return 1;
    case 'followup':
    case 'follow_up':
      return 2;
    case 'meeting':
      return 3;
    case 'installation':
      return 4;
    case 'maintenance':
      return 5;
    case 'reminder':
      return 6;
    default:
      return 99;
  }
}

class ActivityModel {
  ActivityModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.details,
    this.entityType,
    this.entityId,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String userName;
  final String action;
  final String details;
  final String? entityType;
  final int? entityId;
  final DateTime createdAt;

  factory ActivityModel.fromMap(Map<String, Object?> map) =>
      ActivityModel(
        id: _toInt(map['id']) ?? 0,
        userId: _toInt(map['userId'] ?? map['user_id']) ?? 0,
        userName: (
          map['fullName'] ??
          map['username'] ??
          map['userName'] ??
          map['user_name'] ??
          ''
        ).toString(),
        action: (map['action'] ?? '').toString(),
        details: (
          map['description'] ??
          map['details'] ??
          ''
        ).toString(),
        entityType: (
          map['entity'] ??
          map['entityType'] ??
          map['entity_type']
        )?.toString(),
        entityId: _toInt(map['entityId'] ?? map['entity_id']),
        createdAt:
            _dateValue(map['createdAt'] ?? map['created_at']) ??
            DateTime.now(),
      );

  Map<String, Object?> toMap() => {
        'user_id': userId,
        'user_name': userName,
        'action': action,
        'details': details,
        'entity_type': entityType,
        'entity_id': entityId,
        'created_at': createdAt.toIso8601String(),
      };
}

String _roleText(dynamic value) {
  if (value is num) {
    switch (value.toInt()) {
      case 1:
        return 'Admin';
      case 2:
        return 'Engineer';
      case 3:
        return 'Sales';
      case 4:
        return 'Accountant';
      case 5:
        return 'Manager';
    }
  }
  return value?.toString() ?? '';
}

bool _toBool(dynamic value, {bool defaultValue = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1') return true;
    if (v == 'false' || v == '0') return false;
  }
  return defaultValue;
}

DateTime? _dateValue(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  return DateTime.tryParse(value.toString());
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
