import 'package:flutter_test/flutter_test.dart';
import 'package:rsgs/core/models/app_models.dart';
import 'package:rsgs/core/permissions/user_role.dart';
import 'package:rsgs/core/utils/deterministic_color.dart';

void main() {
  test('deterministic colors are stable and handle empty input', () {
    expect(DeterministicColor.getColor('customer-1'), DeterministicColor.getColor('customer-1'));
    expect(DeterministicColor.getColor(''), DeterministicColor.getColor(''));
  });

  test('roles parse API values and reject unknown values', () {
    expect(UserRole.fromString('1'), UserRole.admin);
    expect(UserRole.fromString('manager'), UserRole.manager);
    expect(() => UserRole.fromString('unknown'), throwsFormatException);
    expect(UserRole.admin.permissions.length, AppPermission.values.length);
    expect(UserRole.sales.can(AppPermission.manageCustomers), isTrue);
    expect(UserRole.engineer.can(AppPermission.manageUsers), isFalse);
  });

  test('project model supports API casing, defaults, and serialization', () {
    final project = ProjectModel.fromMap({
      'id': '4', 'projectNumber': 'P-4', 'name': 'Solar', 'customerId': '2',
      'status': 'in_progress', 'totalValue': '125.5', 'totalKW': 3,
    });
    expect(project.id, 4);
    expect(project.status, 'In Progress');
    expect(project.totalValue, 125.5);
    expect(project.toApiCreateJson()['status'], 4);
  });

  test('notification and calendar models normalize enum values and booleans', () {
    final notification = NotificationModel.fromMap({'id': 1, 'title': 'T', 'message': 'M', 'type': 5, 'is_read': '1'});
    final event = CalendarEventModel.fromMap({'id': 2, 'title': 'E', 'eventDate': '2026-01-01T00:00:00Z', 'type': 2, 'is_completed': 1});
    expect(notification.type, 'follow_up');
    expect(notification.isRead, isTrue);
    expect(event.type, 'follow_up');
    expect(event.isCompleted, isTrue);
  });
}
