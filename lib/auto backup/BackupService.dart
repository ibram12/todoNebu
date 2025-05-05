import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class BackupService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );
  final _secureStorage = const FlutterSecureStorage();

  bool _isSignedIn = false;
  bool _isBackingUp = false;
  double _backupProgress = 0;
  String? _lastBackupTime;
  String? _lastError;

  bool get isSignedIn => _isSignedIn;
  bool get isBackingUp => _isBackingUp;
  double get backupProgress => _backupProgress;
  String? get lastBackupTime => _lastBackupTime;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    try {
      _isSignedIn = _auth.currentUser != null;
      notifyListeners();
    } catch (e) {
      print(e.toString());
      _lastError = 'Initialization failed: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> signIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      _isSignedIn = true;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Authentication failed: ${e.toString()}';
      _isSignedIn = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    _isSignedIn = false;
    notifyListeners();
  }

  Future<drive.DriveApi> _getDriveApi() async {
    if (!_isSignedIn) throw Exception('Not signed in');

    final User? user = _auth.currentUser;
    if (user == null) throw Exception('User not found');

    final String? token = await user.getIdToken();
    if (token == null) throw Exception('No access token');

    return drive.DriveApi(AuthenticatedClient(token));
  }

  Future<void> performBackup() async {
    if (_isBackingUp) return;

    _isBackingUp = true;
    _backupProgress = 0;
    _lastError = null;
    notifyListeners();

    try {
      final data = await _getAppData();
      final jsonData = jsonEncode(data);
      final driveApi = await _getDriveApi();

      final file = drive.File()
        ..name = 'backup_${DateTime.now().toIso8601String()}.json'
        ..parents = ['appDataFolder'];

      final bytes = utf8.encode(jsonData);
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
      );

      final uploadRequest = driveApi.files.create(file, uploadMedia: media);

      // uploadRequest.upload.onProgress.listen((progress) {
      //   if (progress.totalBytes != null) {
      //     _backupProgress =
      //         progress.bytes.toDouble() / progress.totalBytes.toDouble();
      //     notifyListeners();
      //   }
      // });

      await uploadRequest;

      _lastBackupTime = DateTime.now().toString();
      _isBackingUp = false;
      _backupProgress = 1.0;
      notifyListeners();
    } catch (e) {
      _isBackingUp = false;
      _lastError = 'Backup failed: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> restoreFromBackup() async {
    try {
      final driveApi = await _getDriveApi();

      final files = await driveApi.files.list(
        spaces: 'appDataFolder',
        orderBy: 'createdTime desc',
        pageSize: 1,
      );

      if (files.files == null || files.files!.isEmpty) {
        throw Exception('No backup files found');
      }

      final fileId = files.files!.first.id!;
      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await response.stream.expand((chunk) => chunk).toList();
      final jsonData = utf8.decode(bytes);
      final data = jsonDecode(jsonData);

      // Implement your restore logic here
      // await _secureStorage.write(key: 'restored_data', value: jsonData);

      _lastBackupTime = 'Restored from ${files.files!.first.createdTime}';
      notifyListeners();
    } catch (e) {
      _lastError = 'Restore failed: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _getAppData() async {
    return {
      'app_settings': await _secureStorage.read(key: 'settings'),
      'user_data': await _secureStorage.read(key: 'user_data'),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

class AuthenticatedClient extends http.BaseClient {
  final String _token;
  final http.Client _inner = http.Client();

  AuthenticatedClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}
