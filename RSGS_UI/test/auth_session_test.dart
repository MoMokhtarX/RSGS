import 'package:flutter_test/flutter_test.dart';
import 'package:rsgs/core/services/auth_session_service.dart';
import 'package:rsgs/core/services/auth_token_storage.dart';
import 'package:rsgs/features/auth/data/auth_repository.dart';
import 'package:rsgs/core/permissions/user_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('session save, restore and clear are lossless', () async {
    final session = AuthSessionService(tokenStorage: MemoryAuthTokenStorage());
    expect(await session.restore(), isNull);
    await session.save(id: 4, username: 'user', fullName: 'User Name', email: 'user@test', role: 'Sales', token: 'token');
    expect(await session.restore(), {
      'id': 4, 'username': 'user', 'fullName': 'User Name', 'email': 'user@test', 'role': 'Sales', 'token': 'token',
    });
    await session.clear();
    expect(await session.restore(), isNull);
  });

  test('authentication user parses supported input and rejects malformed data', () {
    final user = AuthUser.fromJson({'id': '4', 'username': 'u', 'fullName': 'User', 'email': 'u@test', 'role': '3', 'token': 't'});
    expect(user.id, 4);
    expect(user.role, UserRole.sales);
    expect(user.toJson()['role'], 'Sales');
    expect(() => AuthUser.fromJson({'id': 1}), throwsFormatException);
  });
}
