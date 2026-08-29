import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_storage.dart';

class AuthSessionService {
  static const _userIdKey = 'auth.userId';
  static const _usernameKey = 'auth.username';
  static const _fullNameKey = 'auth.fullName';
  static const _emailKey = 'auth.email';
  static const _roleKey = 'auth.role';

  AuthSessionService({AuthTokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? SecureAuthTokenStorage();

  final AuthTokenStorage _tokenStorage;

  Future<void> save({
    required int id,
    required String username,
    required String fullName,
    required String email,
    required String role,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await _tokenStorage.write(token);
    await Future.wait([
      prefs.setInt(_userIdKey, id),
      prefs.setString(_usernameKey, username),
      prefs.setString(_fullNameKey, fullName),
      prefs.setString(_emailKey, email),
      prefs.setString(_roleKey, role),
      // Remove any legacy plaintext token written by older versions.
      prefs.remove('auth.token'),
    ]);
  }

  Future<Map<String, dynamic>?> restore() async {
    final prefs = await SharedPreferences.getInstance();

    final token = await _tokenStorage.read();
    final id = prefs.getInt(_userIdKey);
    final username = prefs.getString(_usernameKey);
    final fullName = prefs.getString(_fullNameKey);
    final email = prefs.getString(_emailKey);
    final role = prefs.getString(_roleKey);

    if (token == null ||
        token.isEmpty ||
        id == null ||
        username == null ||
        fullName == null ||
        email == null ||
        role == null) {
      return null;
    }

    return {
      'id': id,
      'username': username,
      'fullName': fullName,
      'email': email,
      'role': role,
      'token': token,
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await _tokenStorage.delete();
    await Future.wait([
      prefs.remove(_userIdKey),
      prefs.remove(_usernameKey),
      prefs.remove(_fullNameKey),
      prefs.remove(_emailKey),
      prefs.remove(_roleKey),
      // Remove the legacy plaintext token if it exists.
      prefs.remove('auth.token'),
    ]);
  }
}
