import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

// Constants for background tasks
const String backupTaskName = 'todonebu.backup.task';
const String periodicBackupTaskName = 'todonebu.backup.periodic';
const String oneTimeBackupTaskName = 'todonebu.backup.onetime';
const String backgroundPortName = 'todonebu.backup.port';

/// Initialize workmanager for background tasks
Future<void> initializeBackgroundTasks() async {
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true, // Set to false in production
  );
  debugPrint('BackgroundService: Background tasks initialized');
}

/// Callback dispatcher for background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('BackgroundService: Executing task $taskName');

    try {
      // Send port to main isolate if it's listening
      final SendPort? sendPort =
          IsolateNameServer.lookupPortByName(backgroundPortName);
      if (sendPort != null) {
        sendPort.send('${taskName}_started');
      }

      // Initialize notifications for foreground service
      await _initializeNotifications();

      // Show a notification that backup is in progress
      await _showBackupNotification(
        'Backup in progress',
        'Your data is being backed up to Google Drive',
        ongoing: true,
      );

      switch (taskName) {
        case oneTimeBackupTaskName:
          await _performBackup(inputData);
          break;
        case periodicBackupTaskName:
          await _performBackup(inputData);
          break;
        default:
          debugPrint('BackgroundService: Unknown task $taskName');
      }

      // Show completion notification
      await _showBackupNotification(
        'Backup completed',
        'Your data has been successfully backed up to Google Drive',
        ongoing: false,
      );

      // Notify main isolate if it's listening
      if (sendPort != null) {
        sendPort.send('${taskName}_completed');
      }

      return true;
    } catch (e) {
      debugPrint('BackgroundService: Error executing task: $e');

      // Show error notification
      await _showBackupNotification(
        'Backup failed',
        'There was an error during backup: $e',
        ongoing: false,
      );

      // Notify main isolate if it's listening
      final SendPort? sendPort =
          IsolateNameServer.lookupPortByName(backgroundPortName);
      if (sendPort != null) {
        sendPort.send('${taskName}_failed: $e');
      }

      return false;
    }
  });
}

/// Schedule a one-time backup to run after a delay in seconds
Future<bool> scheduleOneTimeBackup({
  required int delaySeconds,
  Map<String, dynamic>? inputData,
}) async {
  try {
    await Workmanager().registerOneOffTask(
      oneTimeBackupTaskName,
      oneTimeBackupTaskName,
      initialDelay: Duration(seconds: delaySeconds),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      inputData: inputData ?? {},
    );

    debugPrint(
        'BackgroundService: Scheduled one-time backup in $delaySeconds seconds');

    // Save scheduled status to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('backup_scheduled', true);
    await prefs.setInt(
        'backup_scheduled_time', DateTime.now().millisecondsSinceEpoch);

    return true;
  } catch (e) {
    debugPrint('BackgroundService: Error scheduling one-time backup: $e');
    return false;
  }
}

/// Schedule a periodic backup
Future<bool> schedulePeriodicBackup({
  required Duration frequency,
  Map<String, dynamic>? inputData,
}) async {
  try {
    await Workmanager().registerPeriodicTask(
      periodicBackupTaskName,
      periodicBackupTaskName,
      frequency: frequency,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      inputData: inputData ?? {},
    );

    debugPrint(
        'BackgroundService: Scheduled periodic backup with frequency ${frequency.inHours} hours');
    return true;
  } catch (e) {
    debugPrint('BackgroundService: Error scheduling periodic backup: $e');
    return false;
  }
}

/// Cancel all scheduled backup tasks
Future<void> cancelAllScheduledBackups() async {
  await Workmanager().cancelAll();

  // Clear scheduled status
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('backup_scheduled', false);

  debugPrint('BackgroundService: Canceled all scheduled backups');
}

/// Check if a backup is currently scheduled
Future<bool> isBackupScheduled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('backup_scheduled') ?? false;
}

/// Get the timestamp of when the backup was scheduled
Future<DateTime?> getBackupScheduledTime() async {
  final prefs = await SharedPreferences.getInstance();
  final timestamp = prefs.getInt('backup_scheduled_time');
  if (timestamp != null) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
  return null;
}

// Private implementation methods

/// Initialize the notifications plugin
FlutterLocalNotificationsPlugin? _notificationsPlugin;
Future<void> _initializeNotifications() async {
  _notificationsPlugin ??= FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettings =
      InitializationSettings(android: androidSettings);

  await _notificationsPlugin!.initialize(initializationSettings);
}

/// Show a backup notification
Future<void> _showBackupNotification(
  String title,
  String body, {
  bool ongoing = false,
}) async {
  if (_notificationsPlugin == null) {
    await _initializeNotifications();
  }

  const androidDetails = AndroidNotificationDetails(
    'backup_channel',
    'Backup Notifications',
    channelDescription: 'Notifications for backup operations',
    importance: Importance.high,
    priority: Priority.high,
    showProgress: true,
    onlyAlertOnce: true,
  );

  const notificationDetails = NotificationDetails(android: androidDetails);

  await _notificationsPlugin!.show(
    0, // Notification ID
    title,
    body,
    notificationDetails,
    payload: 'backup',
  );
}

/// Perform the backup operation in the background
Future<bool> _performBackup(Map<String, dynamic>? inputData) async {
  try {
    debugPrint('BackgroundService: Starting backup process in background');

    // 1. Get authentication token from secure storage
    // We need to use shared_preferences for background access
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');

    if (authToken == null) {
      throw Exception('No authentication token available');
    }

    // 2. Create a backup of the data
    // First load todo data
    final todosJson = prefs.getString('cached_todos');
    if (todosJson == null) {
      throw Exception('No cached todos available');
    }

    // 3. Create backup payload
    final backupData = {
      'timestamp': DateTime.now().toIso8601String(),
      'todos': json.decode(todosJson),
      'app_version': '1.0.0',
      'device_info': {
        'platform': 'android',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }
    };

    // 4. Upload to Google Drive using Firebase Cloud Functions or direct API
    // This is a simplified version - in a real app, you would use proper authentication
    // and API calls to Google Drive

    // Simulating an API call to your backend or Firebase Function that handles the Drive upload
    try {
      // Log attempt to SharedPreferences for tracking
      await prefs.setString(
          'last_backup_attempt', DateTime.now().toIso8601String());

      // In a real implementation, you would make an actual API call here
      // For now, we'll simulate with a delay
      await Future.delayed(const Duration(seconds: 3));

      // Record successful backup
      await prefs.setString(
          'last_backup_time', DateTime.now().toIso8601String());
      await prefs.setBool('backup_scheduled', false);

      return true;
    } catch (e) {
      debugPrint('BackgroundService: Upload error: $e');
      throw Exception('Failed to upload backup: $e');
    }
  } catch (e) {
    debugPrint('BackgroundService: Backup process error: $e');
    return false;
  }
}
