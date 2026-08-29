import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';

import '../../../core/network/api_client.dart';
import '../models/user_management_models.dart';

class UsersRepository {
  UsersRepository(this._api);

  final ApiClient _api;

  Future<List<ManagedUser>> getAll() async {
    final response = await _api.get('/api/Users');
    return _list(response).map(ManagedUser.fromMap).toList();
  }

  Future<ManagedUser> create({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required int role,
  }) async {
    final response = await _api.post(
      '/api/Users',
      data: {
        'username': username.trim(),
        'password': password,
        'fullName': fullName.trim(),
        'email': email.trim(),
        'role': role,
      },
    );
    return ManagedUser.fromMap(_object(response));
  }

  Future<ManagedUser> update(
    int id, {
    required String fullName,
    required String email,
    required int role,
    required bool isActive,
  }) async {
    final response = await _api.put(
      '/api/Users/$id',
      data: {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'role': role,
        'isActive': isActive,
      },
    );
    return ManagedUser.fromMap(_object(response));
  }

  Future<void> resetPassword(int id, String password) async {
    await _api.post(
      '/api/Users/$id/reset-password',
      data: {'newPassword': password},
    );
  }

  Future<void> setActive(int id, bool active) async {
    await _api.put('/api/Users/$id/${active ? 'enable' : 'disable'}');
  }

  List<Map<String, dynamic>> _list(dynamic response) {
    if (response is List) {
      return response.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final data = map['data'] ?? map['items'];
      if (data is List) {
        return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return const [];
  }

  Map<String, dynamic> _object(dynamic response) {
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      if (map.containsKey('id')) return map;
      final data = map['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    throw const FormatException('Invalid user response.');
  }
}

final usersRepositoryProvider = Provider<UsersRepository>(
  (ref) => UsersRepository(ref.watch(apiClientProvider)),
);

final usersProvider = FutureProvider<List<ManagedUser>>(
  (ref) { ref.watch(dataRefreshVersionProvider); return ref.watch(usersRepositoryProvider).getAll(); },
);
