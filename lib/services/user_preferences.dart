import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserPreferences {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyUserPhoto = 'user_photo';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Save user login info
  Future<void> saveUserLoginInfo({
    required String userId,
    required String? email,
    required String? displayName,
    required String? photoUrl,
  }) async {
    await _storage.write(key: _keyIsLoggedIn, value: 'true');
    await _storage.write(key: _keyUserId, value: userId);

    if (email != null) {
      await _storage.write(key: _keyUserEmail, value: email);
    }

    if (displayName != null) {
      await _storage.write(key: _keyUserName, value: displayName);
    }

    if (photoUrl != null) {
      await _storage.write(key: _keyUserPhoto, value: photoUrl);
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final value = await _storage.read(key: _keyIsLoggedIn);
    return value == 'true';
  }

  // Get user info
  Future<Map<String, String?>> getUserInfo() async {
    final userId = await _storage.read(key: _keyUserId);
    final email = await _storage.read(key: _keyUserEmail);
    final displayName = await _storage.read(key: _keyUserName);
    final photoUrl = await _storage.read(key: _keyUserPhoto);

    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
    };
  }

  // Clear user login info
  Future<void> clearUserInfo() async {
    await _storage.deleteAll();
  }
}
