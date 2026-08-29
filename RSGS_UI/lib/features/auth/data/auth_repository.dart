import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/permissions/user_role.dart';
import '../../../core/services/auth_session_service.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    this.token,
  });

  final int id;
  final String username;
  final String fullName;
  final String email;
  final UserRole role;
  final String? token;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = _toInt(json['id']);
    final username = json['username']?.toString();
    final fullName = json['fullName']?.toString();
    final email = json['email']?.toString();
    final role = json['role']?.toString();

    if (id == null ||
        username == null ||
        fullName == null ||
        email == null ||
        role == null) {
      throw const FormatException('Invalid authentication response.');
    }

    return AuthUser(
      id: id,
      username: username,
      fullName: fullName,
      email: email,
      role: UserRole.fromString(role),
      token: json['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'email': email,
        'role': role.label,
        'token': token,
      };

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;
  final AuthSessionService _session = AuthSessionService();

  Future<AuthUser?> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    try {
      final response = await _api.post(
        '/api/Auth/login',
        data: {
          'username': username.trim(),
          'password': password,
        },
      );

      if (response is! Map) {
        return null;
      }

      final user = AuthUser.fromJson(
        Map<String, dynamic>.from(response),
      );

      final token = user.token;
      if (token == null || token.isEmpty || _isTokenExpired(token)) {
        _api.setToken(null);
        return null;
      }

      _api.setToken(token);

      if (rememberMe) {
        await _session.save(
          id: user.id,
          username: user.username,
          fullName: user.fullName,
          email: user.email,
          role: user.role.label,
          token: token,
        );
      } else {
        await _session.clear();
      }

      return user;
    } on ApiException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  void setSessionToken(String? token) {
    if (token == null || token.isEmpty || _isTokenExpired(token)) {
      _api.setToken(null);
      return;
    }

    _api.setToken(token);
  }

  void setUnauthorizedHandler(VoidCallback? handler) {
    _api.setUnauthorizedHandler(handler);
  }

  Future<AuthUser?> restoreSession() async {
    final saved = await _session.restore();

    if (saved == null) {
      _api.setToken(null);
      return null;
    }

    final token = saved['token']?.toString();

    if (token == null || token.isEmpty || _isTokenExpired(token)) {
      await _session.clear();
      _api.setToken(null);
      return null;
    }

    try {
      final user = AuthUser.fromJson(
        Map<String, dynamic>.from(saved),
      );

      _api.setToken(token);
      return user;
    } catch (_) {
      await _session.clear();
      _api.setToken(null);
      return null;
    }
  }

  Future<void> clearSession() async {
    _api.setToken(null);
    await _session.clear();
  }

  Future<List<UserModel>> getEngineers() async {
    final response = await _api.get('/api/Users');

    dynamic data = response;

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      data = map['items'] ?? map['data'];
    }

    if (data is! List) {
      return const <UserModel>[];
    }

    return data
        .whereType<Map>()
        .map(
          (e) => UserModel.fromMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .where((u) => u.role == 'Engineer')
        .toList();
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(normalized)),
      );

      if (payload is! Map) return true;

      final exp = payload['exp'];
      if (exp is num) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(
          exp.toInt() * 1000,
          isUtc: true,
        );
        return !expiry.isAfter(DateTime.now().toUtc());
      }

      return false;
    } catch (_) {
      return true;
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final engineersProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.watch(authRepositoryProvider).getEngineers();
});

class AuthState {
  const AuthState({this.user});

  final AuthUser? user;

  bool get isAuthenticated => user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository) : super(const AuthState()) {
    _repository.setUnauthorizedHandler(_handleUnauthorized);
  }

  final AuthRepository _repository;

  Future<String?> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return 'enter_credentials';
    }

    try {
      final user = await _repository.login(
        username,
        password,
        rememberMe: rememberMe,
      );

      if (user == null) {
        return 'invalid_credentials';
      }

      state = AuthState(user: user);
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        return 'invalid_credentials';
      }

      return e.message;
    } on FormatException {
      return 'invalid_credentials';
    } catch (_) {
      return 'invalid_credentials';
    }
  }

  Future<void> restoreSession() async {
    final saved = await _repository.restoreSession();

    if (saved == null) {
      state = const AuthState();
      return;
    }

    state = AuthState(user: saved);
  }

  Future<void> logout() async {
    await _repository.clearSession();
    state = const AuthState();
  }

  void _handleUnauthorized() {
    unawaited(_repository.clearSession());
    if (mounted) {
      state = const AuthState();
    }
  }

  @override
  void dispose() {
    _repository.setUnauthorizedHandler(null);
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(
    ref.watch(authRepositoryProvider),
  );


  return notifier;
});

final currentUserProvider = Provider<AuthUser?>(
  (ref) => ref.watch(authProvider).user,
);
