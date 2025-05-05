import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/BackupModel.dart';
import '../models/TodoModel.dart';
import 'background_service.dart';
import 'drive_service.dart';

enum BackupStatus {
  idle,
  inProgress,
  completed,
  failed,
}

class BackupService extends ChangeNotifier {
  final FirebaseAuth _auth;
  GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;
  final FlutterSecureStorage _secureStorage;
  final DriveService _driveService;

  // State variables
  BackupStatus _status = BackupStatus.idle;
  String? _statusMessage;
  double _progress = 0.0;
  String? _lastBackupTime;
  String? _lastError;
  bool _isInitialized = false;
  bool _isSignedIn = false;

  // For image tracking
  final Map<String, List<String>> _todoImageMap = {};
  final List<ImageReference> _imageReferences = [];

  // Constants
  static const String backupFolderName = 'ToDoneBu_Backups';
  static const String appSettingsKey = 'app_settings';

  // Getters
  BackupStatus get status => _status;
  String? get statusMessage => _statusMessage;
  double get progress => _progress;
  String? get lastBackupTime => _lastBackupTime;
  String? get lastError => _lastError;
  bool get isInitialized => _isInitialized;
  bool get isSignedIn => _isSignedIn;
  bool get isBackingUp => _status == BackupStatus.inProgress;

  BackupService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
    FlutterSecureStorage? secureStorage,
    DriveService? driveService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: [
                'https://www.googleapis.com/auth/drive.appdata',
                'https://www.googleapis.com/auth/drive.file',
                'https://www.googleapis.com/auth/drive',
              ],
            ),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _driveService = driveService ?? DriveService();

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if user is already signed in
      _isSignedIn = _auth.currentUser != null;

      // Load last backup time if available
      _lastBackupTime = await _secureStorage.read(key: 'last_backup_time');
      print('Initialize: loaded lastBackupTime = $_lastBackupTime');

      if (_lastBackupTime == null) {
        // Try to find the most recent backup file and use its timestamp
        try {
          final files = await _driveService.listBackupFiles();
          if (files.isNotEmpty && files.first.name != null) {
            final fileName = files.first.name!;
            if (fileName.contains('_') && fileName.contains('.')) {
              final timestamp = fileName.split('_').last.split('.').first;
              if (timestamp.isNotEmpty) {
                final date =
                    DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
                _lastBackupTime = date.toString();
                await _secureStorage.write(
                    key: 'last_backup_time', value: _lastBackupTime!);
                print(
                    'Initialize: recovered lastBackupTime = $_lastBackupTime from file');
              }
            }
          }
        } catch (e) {
          print('Error trying to recover backup time: $e');
        }
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _lastError = 'Initialization failed: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Sign in using Google
  Future<bool> signIn() async {
    try {
      // Create a new GoogleSignIn instance with explicit scopes
      final googleSignIn = GoogleSignIn(
        scopes: [
          'https://www.googleapis.com/auth/drive.file', // Required for file uploads
          'https://www.googleapis.com/auth/drive.appdata', // For AppData folder access
        ],
      );

      // Force sign out first to ensure we get a fresh auth flow
      await googleSignIn.signOut();

      // Request sign in with the scopes
      print('Requesting sign in with scopes: ${googleSignIn.scopes}');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        print('User cancelled sign in');
        return false;
      }

      print('Signed in as: ${googleUser.email}');
      print('Drive access requested');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      _isSignedIn = true;
      _lastError = null;

      // Store the user's GoogleSignIn for future use
      _googleSignIn = googleSignIn;

      notifyListeners();
      return true;
    } catch (e) {
      print('Authentication error: ${e.toString()}');
      _lastError = 'Authentication failed: ${e.toString()}';
      _isSignedIn = false;
      notifyListeners();
      return false;
    }
  }

  /// Force sign out and sign in again to refresh permissions
  Future<bool> reauthorize() async {
    try {
      // Sign out
      await _googleSignIn.signOut();

      // Sign in again with proper scopes
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      print('Reauthorized with Google account: ${googleUser.email}');
      print('Requested scopes: ${_googleSignIn.scopes.join(", ")}');
      print(
          'Granted scopes: ${googleUser.serverAuthCode != null ? "authorized" : "unknown"}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      _isSignedIn = true;
      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Reauthorization failed: ${e.toString()}';
      _isSignedIn = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      _isSignedIn = false;
      notifyListeners();
    } catch (e) {
      _lastError = 'Sign out failed: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Ensure user is properly authenticated for Drive operations
  Future<bool> ensureAuthenticated() async {
    debugPrint('ensureAuthenticated: Checking authentication status');

    // Check if Firebase user exists
    if (_auth.currentUser == null) {
      debugPrint(
          'ensureAuthenticated: No Firebase user, authentication required');
      return false;
    }

    // Check if Google account is connected
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      if (account == null) {
        debugPrint(
            'ensureAuthenticated: No Google account connected, need interactive sign-in');
        return false;
      }

      // Verify we have a valid access token
      final GoogleSignInAuthentication auth = await account.authentication;
      if (auth.accessToken == null) {
        debugPrint('ensureAuthenticated: No access token available');
        return false;
      }

      debugPrint(
          'ensureAuthenticated: Successfully authenticated as ${account.email}');
      debugPrint(
          'ensureAuthenticated: Token available (length: ${auth.accessToken!.length})');
      return true;
    } catch (e) {
      debugPrint('ensureAuthenticated: Error checking authentication: $e');
      return false;
    }
  }

  /// Perform backup operation
  Future<bool> performBackup() async {
    debugPrint('performBackup: Starting backup process');

    // First ensure user is authenticated
    if (!(await ensureAuthenticated())) {
      debugPrint(
          'performBackup: Not properly authenticated, attempting sign-in');
      final signInSuccess = await signIn();
      if (!signInSuccess) {
        _lastError = 'Authentication failed. Please sign in first.';
        notifyListeners();
        return false;
      }
    }

    if (_status == BackupStatus.inProgress) {
      debugPrint('performBackup: Backup already in progress');
      return false;
    }

    _status = BackupStatus.inProgress;
    _progress = 0.0;
    _statusMessage = 'Starting backup...';
    _lastError = null;
    notifyListeners();

    debugPrint('performBackup: initial lastBackupTime = $_lastBackupTime');

    try {
      // Step 1: Fetch todos
      _updateStatus('Fetching todos...', 0.1);
      final todos = await _fetchTodos();
      print('performBackup: fetched ${todos.length} todos');

      // Even if there are no todos, we still want to create a backup file
      // with app settings and empty todos list

      // Step 2: Collect images (skip if no todos)
      if (todos.isNotEmpty) {
        _updateStatus('Collecting images...', 0.2);
        await _collectImages(todos);

        // Step 3: Upload images
        _updateStatus('Uploading images...', 0.3);
        await _uploadImages();
      } else {
        _updateStatus('No todos found, skipping image collection...', 0.3);
      }

      // Step 4: Create backup data object
      _updateStatus('Preparing backup data...', 0.7);
      final backupData = await _createBackupData(todos);

      // Step 5: Upload JSON to appDataFolder
      _updateStatus('Uploading backup file...', 0.9);
      final fileName =
          'todonebu_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      await _driveService.uploadJsonToAppData(fileName, backupData.toJson());
      print('performBackup: uploaded backup file $fileName');

      // Step 6: Save backup time
      final now = DateTime.now().toString();
      print('performBackup: about to save lastBackupTime = $now');

      try {
        await _secureStorage.write(key: 'last_backup_time', value: now);
        print('performBackup: write to secure storage completed');
      } catch (e) {
        print('performBackup: ERROR writing to secure storage: $e');
      }

      _lastBackupTime = now;
      print('performBackup: set _lastBackupTime to: $_lastBackupTime');

      notifyListeners(); // Explicitly notify to update UI elements depending on lastBackupTime
      print('performBackup: called notifyListeners()');

      _updateStatus('Backup completed successfully', 1.0);
      _completeBackup();
      return true;
    } catch (e) {
      print('performBackup: ERROR during backup: $e');
      _status = BackupStatus.failed;
      _lastError = 'Backup failed: ${e.toString()}';
      _statusMessage = 'Backup failed';
      notifyListeners();
      return false;
    }
  }

  /// Restore from the most recent backup
  Future<bool> restoreFromBackup() async {
    if (!_isSignedIn) {
      _lastError = 'Not signed in. Please sign in first.';
      notifyListeners();
      return false;
    }

    if (_status == BackupStatus.inProgress) {
      return false;
    }

    _status = BackupStatus.inProgress;
    _progress = 0.0;
    _statusMessage = 'Starting restore...';
    _lastError = null;
    notifyListeners();

    try {
      // Step 1: List backup files
      _updateStatus('Finding backup files...', 0.1);
      final backupFiles = await _driveService.listBackupFiles();

      if (backupFiles.isEmpty) {
        _lastError = 'No backup files found';
        _status = BackupStatus.failed;
        notifyListeners();
        return false;
      }

      // Step 2: Download the most recent backup
      _updateStatus('Downloading backup...', 0.3);
      final latestBackup = backupFiles.first;
      if (latestBackup.id == null) {
        throw Exception('Invalid backup file ID');
      }

      final backupJson =
          await _driveService.downloadJsonFromAppData(latestBackup.id!);
      final backupData = BackupData.fromJson(backupJson);

      // Step 3: Download images
      _updateStatus('Downloading images...', 0.5);
      final imageDir = await _getImageDirectory();
      for (final image in backupData.images) {
        try {
          final imageBytes = await _driveService.downloadImage(image.driveId);
          final file = File('${imageDir.path}/${image.name}');
          await file.writeAsBytes(imageBytes);
        } catch (e) {
          print('Failed to download image ${image.name}: ${e.toString()}');
          // Continue with other images
        }
      }

      // Step 4: Restore todos to Firestore
      _updateStatus('Restoring todos...', 0.8);
      await _restoreTodosToFirestore(backupData.todos);

      // Step 5: Restore app settings
      _updateStatus('Restoring settings...', 0.9);
      await _restoreAppSettings(backupData.appSettings);

      _updateStatus('Restore completed successfully', 1.0);
      _completeBackup();
      return true;
    } catch (e) {
      _status = BackupStatus.failed;
      _lastError = 'Restore failed: ${e.toString()}';
      _statusMessage = 'Restore failed';
      notifyListeners();
      return false;
    }
  }

  /// Fetch todos from Firestore
  Future<List<ToDo>> _fetchTodos() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');

    final querySnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .get();

    return querySnapshot.docs.map((doc) => ToDo.fromDocument(doc)).toList();
  }

  /// Collect images associated with todos
  Future<void> _collectImages(List<ToDo> todos) async {
    _todoImageMap.clear();
    _imageReferences.clear();

    final imageDir = await _getImageDirectory();
    if (!await imageDir.exists()) {
      return; // No images directory
    }

    // For a real app, you would need a database to track todo-image relationships
    // This is a simplified approach assuming image files follow a naming convention
    final files = await imageDir.list().toList();

    for (final todo in todos) {
      final todoImages = files.whereType<File>().where((file) {
        final fileName = file.path.split('/').last;
        return fileName.startsWith('todo_${todo.id}_');
      }).toList();

      if (todoImages.isNotEmpty) {
        _todoImageMap[todo.id] = todoImages.map((file) => file.path).toList();
      }
    }
  }

  /// Upload images to Google Drive
  Future<void> _uploadImages() async {
    int uploadCount = 0;
    final totalImages = _todoImageMap.values.expand((images) => images).length;

    for (final entry in _todoImageMap.entries) {
      final todoId = entry.key;
      final imagePaths = entry.value;

      for (final imagePath in imagePaths) {
        try {
          final file = File(imagePath);
          final fileName = file.path.split('/').last;

          final fileId =
              await _driveService.uploadImage(file, backupFolderName);

          _imageReferences.add(ImageReference(
            id: fileName,
            name: fileName,
            driveId: fileId,
            todoId: todoId,
            uploadTime: DateTime.now(),
          ));

          uploadCount++;
          _progress = 0.3 +
              (uploadCount / totalImages) * 0.4; // Progress between 0.3-0.7
          notifyListeners();
        } catch (e) {
          print('Failed to upload image $imagePath: ${e.toString()}');
          // Continue with other images
        }
      }
    }
  }

  /// Create the backup data object
  Future<BackupData> _createBackupData(List<ToDo> todos) async {
    // Convert todos to backup format
    final todoBackups = todos.map((todo) {
      final imageIds = _imageReferences
          .where((img) => img.todoId == todo.id)
          .map((img) => img.driveId)
          .toList();

      return TodoBackup.fromToDo(todo, imageIds);
    }).toList();

    // Get app settings
    final settingsJson = await _secureStorage.read(key: appSettingsKey);
    final appSettings = settingsJson != null
        ? Map<String, dynamic>.from(await jsonDecode(settingsJson))
        : <String, dynamic>{};

    return BackupData(
      todos: todoBackups,
      appSettings: appSettings,
      timestamp: DateTime.now(),
      images: _imageReferences,
    );
  }

  /// Restore todos to Firestore
  Future<void> _restoreTodosToFirestore(List<TodoBackup> todos) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');

    final batch = _firestore.batch();
    final todosCollection =
        _firestore.collection('users').doc(user.uid).collection('todos');

    // First, delete existing todos
    final existingTodos = await todosCollection.get();
    for (final doc in existingTodos.docs) {
      batch.delete(doc.reference);
    }

    // Then add restored todos
    for (final todo in todos) {
      final docRef = todosCollection.doc(todo.id);
      batch.set(docRef, {
        'isDone': todo.isDone,
        'title': todo.title,
        'createdAt': Timestamp.fromDate(todo.createdAt),
        if (todo.updatedAt != null)
          'updatedAt': Timestamp.fromDate(todo.updatedAt!),
      });
    }

    await batch.commit();
  }

  /// Restore app settings
  Future<void> _restoreAppSettings(Map<String, dynamic> settings) async {
    await _secureStorage.write(
        key: appSettingsKey, value: jsonEncode(settings));
  }

  /// Get the directory for image storage
  Future<Directory> _getImageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${appDir.path}/images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir;
  }

  /// Update status and progress
  void _updateStatus(String message, double progress) {
    _statusMessage = message;
    _progress = progress;
    notifyListeners();
  }

  /// Complete the backup process
  void _completeBackup() {
    _status = BackupStatus.completed;
    notifyListeners();

    // Reset to idle state after a delay
    Future.delayed(const Duration(seconds: 3), () {
      _status = BackupStatus.idle;
      notifyListeners();
    });
  }

  /// List all backup files from Google Drive
  Future<List<Map<String, dynamic>>> listBackupFiles() async {
    if (!_isSignedIn) {
      _lastError = 'Not signed in. Please sign in first.';
      notifyListeners();
      return [];
    }

    try {
      final files = await _driveService.listBackupFiles();
      return files
          .map((file) => {
                'id': file.id ?? '',
                'name': file.name ?? 'Unnamed Backup',
                'size': file.size ?? 0,
                'createdTime': file.createdTime?.toIso8601String() ?? '',
              })
          .toList();
    } catch (e) {
      _lastError = 'Failed to list backup files: ${e.toString()}';
      notifyListeners();
      return [];
    }
  }

  /// Force a refresh of the backup status by checking secure storage
  Future<void> refreshBackupStatus() async {
    try {
      // Check secure storage for backup time
      final storedTime = await _secureStorage.read(key: 'last_backup_time');
      print('refreshBackupStatus: stored backup time = $storedTime');

      if (storedTime != null && storedTime.isNotEmpty) {
        if (_lastBackupTime != storedTime) {
          _lastBackupTime = storedTime;
          print('refreshBackupStatus: updated lastBackupTime to $storedTime');
          notifyListeners();
        } else {
          print('refreshBackupStatus: lastBackupTime already up-to-date');
        }
      } else {
        print('refreshBackupStatus: no backup time found in secure storage');

        // Try to find backup files if no time found
        try {
          final files = await _driveService.listBackupFiles();
          print('refreshBackupStatus: found ${files.length} backup files');

          if (files.isNotEmpty && files.first.name != null) {
            final fileName = files.first.name!;
            if (fileName.contains('_') && fileName.contains('.')) {
              final timestamp = fileName.split('_').last.split('.').first;
              if (timestamp.isNotEmpty) {
                final date =
                    DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
                _lastBackupTime = date.toString();
                await _secureStorage.write(
                    key: 'last_backup_time', value: _lastBackupTime!);
                print(
                    'refreshBackupStatus: recovered lastBackupTime = $_lastBackupTime from file');
                notifyListeners();
              }
            }
          }
        } catch (e) {
          print('refreshBackupStatus: ERROR trying to recover backup time: $e');
        }
      }
    } catch (e) {
      print('refreshBackupStatus: ERROR checking backup status: $e');
    }
  }

  /// Upload a test JSON file to drive
  Future<void> uploadTestJson(
      String fileName, Map<String, dynamic> data) async {
    debugPrint('uploadTestJson: Starting test upload process');

    // Verify authentication first
    final isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      debugPrint('uploadTestJson: Not authenticated, attempting sign-in');
      final signInSuccess = await signIn();
      if (!signInSuccess) {
        debugPrint('uploadTestJson: Sign-in failed or cancelled');
        throw Exception('Authentication required for uploading');
      }
    }

    debugPrint('uploadTestJson: Preparing to upload test file: $fileName');
    debugPrint(
        'uploadTestJson: Current scopes: ${_googleSignIn.scopes.join(", ")}');

    try {
      // Upload the test file
      final fileId = await _driveService.uploadJsonToAppData(fileName, data);
      debugPrint(
          'uploadTestJson: Test file uploaded successfully with ID: $fileId');

      // Update backup time since this is a successful backup
      final now = DateTime.now().toString();
      await setLastBackupTime(now);
    } catch (e) {
      debugPrint('uploadTestJson: ERROR: ${e.toString()}');
      throw Exception('Failed to upload test JSON: ${e.toString()}');
    }
  }

  /// Manually set the last backup time
  Future<void> setLastBackupTime(String time) async {
    debugPrint('setLastBackupTime: Setting backup time to: $time');
    try {
      await _secureStorage.write(key: 'last_backup_time', value: time);
      debugPrint('setLastBackupTime: Write to secure storage completed');

      _lastBackupTime = time;
      debugPrint(
          'setLastBackupTime: Updated _lastBackupTime = $_lastBackupTime');

      notifyListeners();
      debugPrint('setLastBackupTime: Notified listeners');
    } catch (e) {
      debugPrint('setLastBackupTime: ERROR: $e');
      throw e;
    }
  }

  /// Restore from a specific backup by ID
  Future<bool> restoreSpecificBackup(String backupId) async {
    if (!_isSignedIn) {
      _lastError = 'Not signed in. Please sign in first.';
      notifyListeners();
      return false;
    }

    if (_status == BackupStatus.inProgress) {
      return false;
    }

    _status = BackupStatus.inProgress;
    _progress = 0.0;
    _statusMessage = 'Starting restore...';
    _lastError = null;
    notifyListeners();

    try {
      // Step 1: Download the specific backup
      _updateStatus('Downloading backup...', 0.3);

      final backupJson = await _driveService.downloadJsonFromAppData(backupId);
      final backupData = BackupData.fromJson(backupJson);

      // Step 2: Download images
      _updateStatus('Downloading images...', 0.5);
      final imageDir = await _getImageDirectory();
      for (final image in backupData.images) {
        try {
          final imageBytes = await _driveService.downloadImage(image.driveId);
          final file = File('${imageDir.path}/${image.name}');
          await file.writeAsBytes(imageBytes);
        } catch (e) {
          print('Failed to download image ${image.name}: ${e.toString()}');
          // Continue with other images
        }
      }

      // Step 3: Restore todos to Firestore
      _updateStatus('Restoring todos...', 0.8);
      await _restoreTodosToFirestore(backupData.todos);

      // Step 4: Restore app settings
      _updateStatus('Restoring settings...', 0.9);
      if (backupData.appSettings != null) {
        await _secureStorage.write(
            key: appSettingsKey, value: jsonEncode(backupData.appSettings));
      }

      final now = DateTime.now().toString();
      await _secureStorage.write(key: 'last_restore_time', value: now);

      _updateStatus('Restore completed successfully', 1.0);
      _status = BackupStatus.completed;
      notifyListeners();
      return true;
    } catch (e) {
      _status = BackupStatus.failed;
      _lastError = 'Restore failed: ${e.toString()}';
      _statusMessage = 'Restore failed';
      notifyListeners();
      return false;
    }
  }

  /// Perform a backup in the background with notifications
  Future<bool> performBackgroundBackup() async {
    try {
      _setStatus(BackupStatus.inProgress, 'Starting backup process...');
      notifyListeners();

      // Ensure we're authenticated
      final isAuthenticated = await ensureAuthenticated();
      if (!isAuthenticated) {
        debugPrint(
            'performBackgroundBackup: Not authenticated, trying to sign in');
        final signedIn = await signIn();
        if (!signedIn) {
          _setStatus(BackupStatus.failed, 'Authentication failed');
          return false;
        }
      }

      // Create a backup data object
      _setStatus(BackupStatus.inProgress, 'Collecting data to backup...', 0.1);
      final backupData = await _collectBackupData();

      // Create a timestamp for the backup
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'todonebu_backup_$timestamp.json';

      // Upload JSON to appDataFolder
      _setStatus(BackupStatus.inProgress, 'Uploading backup data...', 0.3);
      final fileId = await _driveService.uploadJsonToAppData(
          fileName, backupData.toJson());
      debugPrint('performBackgroundBackup: JSON uploaded with ID: $fileId');

      // Upload images to regular Google Drive
      _setStatus(BackupStatus.inProgress, 'Uploading images...', 0.5);
      await _uploadPendingImages();

      // Update last backup time
      _lastBackupTime = DateTime.now().toString();
      await _secureStorage.write(
          key: 'last_backup_time', value: _lastBackupTime!);

      _setStatus(BackupStatus.completed, 'Backup completed successfully', 1.0);
      debugPrint('performBackgroundBackup: Backup completed successfully');

      // Notify listeners that the backup is complete
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('performBackgroundBackup error: ${e.toString()}');
      _lastError = 'Backup failed: ${e.toString()}';
      _setStatus(BackupStatus.failed, _lastError!);
      notifyListeners();
      return false;
    }
  }

  /// Schedule a delayed backup that will run after specified seconds
  /// Returns true if the backup was scheduled successfully
  Future<bool> scheduleDelayedBackup({int delaySeconds = 10}) async {
    debugPrint(
        'scheduleDelayedBackup: Scheduling backup with ${delaySeconds}s delay');

    try {
      // First ensure authentication to avoid issues when the backup runs
      if (!(await ensureAuthenticated())) {
        debugPrint(
            'scheduleDelayedBackup: Not authenticated, attempting sign-in');
        final signInSuccess = await signIn();
        if (!signInSuccess) {
          _lastError = 'Authentication failed. Cannot schedule backup.';
          notifyListeners();
          return false;
        }
      }

      // Store a timestamp for when the backup should execute
      final scheduledTime = DateTime.now()
          .add(Duration(seconds: delaySeconds))
          .millisecondsSinceEpoch;
      await _secureStorage.write(
          key: 'scheduled_backup_time', value: scheduledTime.toString());

      // Set status to indicate a backup is scheduled
      _statusMessage = 'Backup scheduled in ${delaySeconds}s';
      notifyListeners();

      debugPrint(
          'scheduleDelayedBackup: Backup scheduled for timestamp $scheduledTime');

      // Start a delayed timer that will trigger the backup
      // Note: This will only work if the app remains open
      Future.delayed(Duration(seconds: delaySeconds), () async {
        debugPrint('scheduleDelayedBackup: Executing delayed backup now');
        // Check if we're still supposed to run this backup
        final scheduledTimeStr =
            await _secureStorage.read(key: 'scheduled_backup_time');
        if (scheduledTimeStr == null) {
          debugPrint('scheduleDelayedBackup: No scheduled backup found');
          return;
        }

        // Clear the scheduled time
        await _secureStorage.delete(key: 'scheduled_backup_time');

        // Perform the actual backup
        await performBackgroundBackup();
      });

      return true;
    } catch (e) {
      debugPrint('scheduleDelayedBackup error: ${e.toString()}');
      _lastError = 'Failed to schedule backup: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Check if there's a pending scheduled backup and execute it if needed
  /// This should be called when the app starts
  Future<void> checkAndRunScheduledBackup() async {
    try {
      final scheduledTimeStr =
          await _secureStorage.read(key: 'scheduled_backup_time');
      if (scheduledTimeStr == null) {
        // No scheduled backup
        return;
      }

      final scheduledTime = int.parse(scheduledTimeStr);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now >= scheduledTime) {
        debugPrint(
            'checkAndRunScheduledBackup: Found pending backup, executing now');
        // Clear the scheduled time first to prevent duplicate executions
        await _secureStorage.delete(key: 'scheduled_backup_time');

        // Run the backup
        await performBackgroundBackup();
      } else {
        // Backup is scheduled for the future, wait for the remaining time
        final remainingMillis = scheduledTime - now;
        final remainingSecs = (remainingMillis / 1000).ceil();

        debugPrint(
            'checkAndRunScheduledBackup: Backup scheduled in $remainingSecs seconds');

        // Schedule the remaining time
        Future.delayed(Duration(milliseconds: remainingMillis), () async {
          // Check again before executing in case it was canceled
          final stillScheduled =
              await _secureStorage.read(key: 'scheduled_backup_time');
          if (stillScheduled != null) {
            await _secureStorage.delete(key: 'scheduled_backup_time');
            await performBackgroundBackup();
          }
        });
      }
    } catch (e) {
      debugPrint('checkAndRunScheduledBackup error: ${e.toString()}');
    }
  }

  /// Helper method to collect all data for backup
  Future<BackupData> _collectBackupData() async {
    try {
      // Clear previous image tracking
      _todoImageMap.clear();
      _imageReferences.clear();

      // Get all todos from Firestore
      final todoCollection = _firestore.collection('todos');
      final todoSnapshot = await todoCollection.get();
      final List<TodoBackup> todoBackups = [];

      // Process each todo
      for (final doc in todoSnapshot.docs) {
        final todoData = doc.data();
        final String id = doc.id;

        // Process images for this todo
        final List<String> imageIds = [];
        if (todoData['images'] != null && todoData['images'] is List) {
          _todoImageMap[id] = [];
          for (final imageUrl in todoData['images']) {
            if (imageUrl is String && imageUrl.isNotEmpty) {
              // Add to pending images to be uploaded
              _todoImageMap[id]!.add(imageUrl);
            }
          }
        }

        // Create TodoBackup object
        final todoBackup = TodoBackup(
          id: id,
          isDone: todoData['isDone'] ?? false,
          title: todoData['title'] ?? '',
          createdAt: (todoData['createdAt'] as Timestamp).toDate(),
          updatedAt: todoData['updatedAt'] != null
              ? (todoData['updatedAt'] as Timestamp).toDate()
              : null,
          imageIds: imageIds,
        );

        todoBackups.add(todoBackup);
      }

      // Get app settings
      final appSettings = await _getAppSettings();

      return BackupData(
        todos: todoBackups,
        appSettings: appSettings,
        timestamp: DateTime.now(),
        images: _imageReferences,
      );
    } catch (e) {
      debugPrint('_collectBackupData error: ${e.toString()}');
      throw Exception('Failed to collect backup data: ${e.toString()}');
    }
  }

  /// Upload all pending images to Google Drive
  Future<void> _uploadPendingImages() async {
    try {
      // If no images to upload, return early
      if (_todoImageMap.isEmpty) {
        return;
      }

      // Calculate total number of images to upload
      int totalImages = 0;
      for (final todoId in _todoImageMap.keys) {
        totalImages += _todoImageMap[todoId]!.length;
      }

      int uploadedCount = 0;

      // Upload each image and track progress
      for (final todoId in _todoImageMap.keys) {
        final images = _todoImageMap[todoId]!;
        for (final imageUrl in images) {
          // Get image file from URL
          final File imageFile = await _getImageFileFromUrl(imageUrl);

          // Upload to Google Drive - using the folder name directly
          final driveId =
              await _driveService.uploadImage(imageFile, backupFolderName);

          // Add to image references
          _imageReferences.add(
            ImageReference(
              id: imageFile.path.split('/').last,
              name: imageFile.path.split('/').last,
              driveId: driveId,
              todoId: todoId,
              uploadTime: DateTime.now(),
            ),
          );

          // Update progress
          uploadedCount++;
          final progress = 0.5 + (uploadedCount / totalImages) * 0.4;
          _setStatus(
              BackupStatus.inProgress,
              'Uploading images (${uploadedCount}/${totalImages})...',
              progress);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('_uploadPendingImages error: ${e.toString()}');
      throw Exception('Failed to upload images: ${e.toString()}');
    }
  }

  /// Helper method to get image file from URL (implement according to your app's structure)
  Future<File> _getImageFileFromUrl(String imageUrl) async {
    // This method should be implemented based on how your app handles images
    // It might involve downloading from a network URL or accessing a local cache

    // Placeholder implementation - replace with your actual logic
    final tempDir = await getTemporaryDirectory();
    final fileName = imageUrl.split('/').last;
    final file = File('${tempDir.path}/$fileName');

    // If the URL points to a local file, just return that file
    if (imageUrl.startsWith('file://')) {
      return File(imageUrl.replaceFirst('file://', ''));
    }

    // For network URLs, you'd need to download the file
    // This is just a placeholder implementation
    if (!file.existsSync()) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        await file.writeAsBytes(response.bodyBytes);
      } catch (e) {
        debugPrint('Failed to download image: $e');
        throw Exception('Failed to download image: $e');
      }
    }

    return file;
  }

  /// Helper method to set status
  void _setStatus(BackupStatus status, String message, [double? progress]) {
    _status = status;
    _statusMessage = message;
    if (progress != null) {
      _progress = progress;
    }
  }

  /// Helper method to get app settings
  Future<Map<String, dynamic>> _getAppSettings() async {
    try {
      // Read app settings from secure storage or other source
      final appSettingsStr = await _secureStorage.read(key: appSettingsKey);
      if (appSettingsStr != null) {
        return jsonDecode(appSettingsStr) as Map<String, dynamic>;
      }

      // Return default settings if none found
      return {
        'version': '1.0.0',
        'lastBackup': _lastBackupTime,
        'theme': 'system',
        'notifications': true,
      };
    } catch (e) {
      debugPrint('Error getting app settings: $e');
      // Return default settings on error
      return {
        'version': '1.0.0',
        'lastBackup': _lastBackupTime,
      };
    }
  }

  /// Download a specific backup file from Google Drive
  Future<Map<String, dynamic>> downloadBackupJson(String fileId) async {
    try {
      debugPrint(
          'downloadBackupJson: Downloading backup file with ID: $fileId');

      // Ensure we're authenticated
      final isAuthenticated = await ensureAuthenticated();
      if (!isAuthenticated) {
        final signedIn = await signIn();
        if (!signedIn) {
          throw Exception('Authentication required to download backup');
        }
      }

      // Download the JSON file
      final jsonData = await _driveService.downloadJsonFromAppData(fileId);
      debugPrint('downloadBackupJson: File downloaded successfully');

      // Validate the data - make sure it has the expected structure
      if (jsonData == null) {
        debugPrint('downloadBackupJson: Received null data from Drive');
        return {'error': 'No data found in backup file'};
      }

      // Ensure required fields exist to prevent null errors
      final validatedData = {
        'timestamp': jsonData['timestamp'],
        'todos': jsonData['todos'] ?? [],
        'appSettings': jsonData['appSettings'] ?? {},
        'images': jsonData['images'] ?? [],
      };

      return validatedData;
    } catch (e) {
      debugPrint('downloadBackupJson error: ${e.toString()}');
      // Return a minimal valid structure instead of throwing
      return {
        'error': 'Failed to download backup: ${e.toString()}',
        'todos': [],
        'appSettings': {},
        'images': [],
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Schedule a reliable background backup using WorkManager
  /// This will continue even if the app is closed
  Future<bool> scheduleReliableBackup({int delaySeconds = 10}) async {
    try {
      debugPrint(
          'scheduleReliableBackup: Setting up background backup in $delaySeconds seconds');

      // First ensure we're authenticated and cache the auth token
      if (!(await ensureAuthenticated())) {
        debugPrint(
            'scheduleReliableBackup: Not authenticated, attempting sign-in');
        final signInSuccess = await signIn();
        if (!signInSuccess) {
          _lastError = 'Authentication failed. Cannot schedule backup.';
          notifyListeners();
          return false;
        }
      }

      // Get the auth token and cache it for background use
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) {
        debugPrint('scheduleReliableBackup: No Google user available');
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final token = googleAuth.accessToken;

      if (token == null) {
        debugPrint('scheduleReliableBackup: No access token available');
        return false;
      }

      // Cache the token in SharedPreferences for background access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);

      // Cache todos for background access
      final todos = await _fetchTodos();
      final todoJsonList = todos
          .map((todo) => {
                'id': todo.id,
                'isDone': todo.isDone,
                'title': todo.title,
                'createdAt': todo.createdAt.toIso8601String(),
                if (todo.updatedAt != null)
                  'updatedAt': todo.updatedAt!.toIso8601String(),
              })
          .toList();

      await prefs.setString('cached_todos', jsonEncode(todoJsonList));

      // Schedule the reliable background backup with WorkManager
      final result = await scheduleOneTimeBackup(
        delaySeconds: delaySeconds,
        inputData: {
          'user_id': _auth.currentUser?.uid ?? '',
          'email': _auth.currentUser?.email ?? '',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      if (result) {
        _statusMessage = 'Backup scheduled to run in $delaySeconds seconds';
        notifyListeners();
        return true;
      } else {
        _lastError = 'Failed to schedule background backup';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('scheduleReliableBackup error: ${e.toString()}');
      _lastError = 'Error scheduling reliable backup: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Cancel any scheduled background backups
  Future<void> cancelScheduledBackups() async {
    await cancelAllScheduledBackups();
    _statusMessage = 'Scheduled backups canceled';
    notifyListeners();
  }
}
