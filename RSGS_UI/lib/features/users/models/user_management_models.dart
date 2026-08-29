import '../../../core/permissions/user_role.dart';

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    this.createdAt,
  });

  final int id;
  final String username;
  final String fullName;
  final String email;
  final UserRole role;
  final bool isActive;
  final DateTime? createdAt;

  factory ManagedUser.fromMap(Map<String, dynamic> map) {
    return ManagedUser(
      id: _int(map['id']) ?? 0,
      username: map['username']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? map['full_name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      role: _role(map['role']),
      isActive: map['isActive'] == true || map['is_active'] == true,
      createdAt: _date(map['createdAt'] ?? map['created_at']),
    );
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static UserRole _role(dynamic value) {
    if (value is num) {
      final number = value.toInt();
      return UserRole.values.firstWhere(
        (r) => r.apiValue == number,
        orElse: () => UserRole.sales,
      );
    }
    return UserRole.fromString(value?.toString() ?? 'Sales');
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
