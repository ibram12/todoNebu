import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

/// Service for interacting with Google Drive
class DriveService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  DriveService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: [
                drive.DriveApi.driveAppdataScope, // For appDataFolder
                drive.DriveApi.driveFileScope, // For regular files
                drive
                    .DriveApi.driveScope, // Full Drive access (might be needed)
                'https://www.googleapis.com/auth/drive.appdata',
                'https://www.googleapis.com/auth/drive.file',
                'https://www.googleapis.com/auth/drive',
              ],
            );

  /// Get authenticated Drive API instance
  Future<drive.DriveApi> getDriveApi() async {
    debugPrint('getDriveApi: Getting authenticated DriveApi instance');

    // Check if Firebase user is signed in
    final User? user = _auth.currentUser;
    if (user == null) {
      debugPrint('getDriveApi: No Firebase user found');
      throw Exception('User not signed in');
    }
    debugPrint('getDriveApi: Firebase user found: ${user.email}');

    // First try to get the current Google Sign-In account silently
    GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();

    // If silent sign-in fails, try interactive sign-in
    if (googleUser == null) {
      debugPrint(
          'getDriveApi: Silent sign-in failed, trying interactive sign-in');
      googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('getDriveApi: Interactive sign-in failed or was cancelled');
        throw Exception('Google Sign-In required');
      }
    }

    debugPrint('getDriveApi: Using Google account: ${googleUser.email}');
    debugPrint(
        'getDriveApi: Requested scopes: ${_googleSignIn.scopes.join(", ")}');

    // Get authentication details
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    if (googleAuth.accessToken == null) {
      debugPrint('getDriveApi: No access token available');
      throw Exception('No Google access token');
    }

    debugPrint(
        'getDriveApi: Access token obtained (length: ${googleAuth.accessToken!.length})');

    // Create authenticated HTTP client for Drive API
    final authClient = AuthenticatedClient(googleAuth.accessToken!);
    return drive.DriveApi(authClient);
  }

  /// Upload JSON data to appDataFolder
  /// Returns the file ID
  Future<String> uploadJsonToAppData(
      String fileName, Map<String, dynamic> jsonData) async {
    try {
      final driveApi = await getDriveApi();

      // Define the file metadata
      final file = drive.File()
        ..name = fileName
        ..mimeType = 'application/json'
        ..parents = ['appDataFolder'];

      // Prepare the file content
      final String jsonString = jsonEncode(jsonData);
      final List<int> bytes = utf8.encode(jsonString);
      final Stream<List<int>> mediaStream = Stream.value(bytes);
      final drive.Media media = drive.Media(mediaStream, bytes.length);

      // Upload the file
      final result = await driveApi.files.create(
        file,
        uploadMedia: media,
      );

      if (result.id == null) {
        throw Exception('Failed to get ID for the uploaded file');
      }

      return result.id!;
    } catch (e) {
      throw Exception('Failed to upload JSON: ${e.toString()}');
    }
  }

  /// Upload an image to regular Google Drive
  /// Returns the file ID
  Future<String> uploadImage(File imageFile, String folderName) async {
    try {
      final driveApi = await getDriveApi();

      // Create backup folder if it doesn't exist
      String? folderId = await _getFolderIdByName(driveApi, folderName);
      folderId ??= await _createFolder(driveApi, folderName);

      // Define the file metadata
      final fileName = path.basename(imageFile.path);
      final file = drive.File()
        ..name = fileName
        ..parents = [folderId];

      // Read the file content
      final bytes = await imageFile.readAsBytes();
      final drive.Media media = drive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: 'image/${path.extension(imageFile.path).substring(1)}',
      );

      // Upload the file
      final result = await driveApi.files.create(
        file,
        uploadMedia: media,
      );

      if (result.id == null) {
        throw Exception('Failed to get ID for the uploaded image');
      }

      return result.id!;
    } catch (e) {
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  /// Download a JSON file from appDataFolder
  Future<Map<String, dynamic>> downloadJsonFromAppData(String fileId) async {
    try {
      final driveApi = await getDriveApi();

      final drive.Media media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataBytes = await _mediaToBytes(media);
      final String jsonString = utf8.decode(dataBytes);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to download JSON: ${e.toString()}');
    }
  }

  /// Download an image from Google Drive
  Future<Uint8List> downloadImage(String fileId) async {
    try {
      final driveApi = await getDriveApi();

      final drive.Media media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      return Uint8List.fromList(await _mediaToBytes(media));
    } catch (e) {
      throw Exception('Failed to download image: ${e.toString()}');
    }
  }

  /// List all backup files in appDataFolder, sorted by creation time
  Future<List<drive.File>> listBackupFiles() async {
    try {
      final driveApi = await getDriveApi();

      final result = await driveApi.files.list(
        spaces: 'appDataFolder',
        orderBy: 'createdTime desc',
        q: "mimeType='application/json'",
      );

      return result.files ?? [];
    } catch (e) {
      throw Exception('Failed to list backup files: ${e.toString()}');
    }
  }

  /// Delete a file from Google Drive
  Future<void> deleteFile(String fileId) async {
    try {
      final driveApi = await getDriveApi();
      await driveApi.files.delete(fileId);
    } catch (e) {
      throw Exception('Failed to delete file: ${e.toString()}');
    }
  }

  /// Find a folder by name
  Future<String?> _getFolderIdByName(
      drive.DriveApi driveApi, String folderName) async {
    final result = await driveApi.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed=false",
      spaces: 'drive',
    );

    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id;
    }

    return null;
  }

  /// Create a folder
  Future<String> _createFolder(
      drive.DriveApi driveApi, String folderName) async {
    final folder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final result = await driveApi.files.create(folder);

    if (result.id == null) {
      throw Exception('Failed to create folder');
    }

    return result.id!;
  }

  /// Convert drive.Media to bytes
  Future<List<int>> _mediaToBytes(drive.Media media) async {
    final completer = Completer<List<int>>();
    final bytes = <int>[];

    media.stream.listen(
      (List<int> newBytes) {
        bytes.addAll(newBytes);
      },
      onDone: () {
        completer.complete(bytes);
      },
      onError: (error) {
        completer.completeError(error);
      },
      cancelOnError: true,
    );

    return completer.future;
  }
}

/// HTTP client that adds authentication to requests
class AuthenticatedClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _client = http.Client();

  AuthenticatedClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}
