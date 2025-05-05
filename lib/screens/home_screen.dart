import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/background_service.dart';
import '../services/backup_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize backup service when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final backupService = Provider.of<BackupService>(context, listen: false);
      if (!backupService.isInitialized) {
        backupService.initialize().then((_) {
          backupService.refreshBackupStatus();
          // Check if there's a pending scheduled backup
          backupService.checkAndRunScheduledBackup();
        });
      } else {
        backupService.refreshBackupStatus();
        // Check if there's a pending scheduled backup
        backupService.checkAndRunScheduledBackup();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ToDoneBu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              await authService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, _) {
          if (authService.user == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final user = authService.user!;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (user.photoURL != null)
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(user.photoURL!),
                  ),
                Text(
                  'Welcome, ${user.displayName ?? 'User'}!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user.email ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                Consumer<BackupService>(
                  builder: (context, backupService, _) {
                    final isBackingUp = backupService.isBackingUp;
                    final hasBackup = backupService.lastBackupTime != null;

                    print(
                        'Consumer rebuilding: isBackingUp=$isBackingUp, hasBackup=$hasBackup');
                    print('lastBackupTime=${backupService.lastBackupTime}');

                    return Column(
                      children: [
                        // Backup button
                        ElevatedButton(
                          onPressed: isBackingUp
                              ? null
                              : () async {
                                  if (!backupService.isInitialized) {
                                    await backupService.initialize();
                                  }

                                  if (!backupService.isSignedIn) {
                                    final signedIn =
                                        await backupService.signIn();
                                    if (!signedIn) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Sign-in required to backup'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                  }

                                  if (backupService.isSignedIn) {
                                    // Show starting backup notification
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Starting backup to Google Drive...'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }

                                    // Perform background backup
                                    final success = await backupService
                                        .performBackgroundBackup();

                                    if (backupService.lastError != null &&
                                        context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text(backupService.lastError!),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    } else if (success && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Backup completed successfully!'),
                                          backgroundColor: Colors.green,
                                          duration: Duration(seconds: 3),
                                        ),
                                      );
                                      _showBackupInfoDialog(
                                          context, backupService);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: isBackingUp
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Backup to Drive',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),

                        // Add new Scheduled Backup button
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: isBackingUp
                              ? null
                              : () async {
                                  if (!backupService.isInitialized) {
                                    await backupService.initialize();
                                  }

                                  if (!backupService.isSignedIn) {
                                    final signedIn =
                                        await backupService.signIn();
                                    if (!signedIn) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Sign-in required to schedule backup'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                  }

                                  // Show starting notification
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Scheduling backup to run in 10 seconds...'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }

                                  // Schedule the backup with 10 second delay
                                  final success = await backupService
                                      .scheduleDelayedBackup(delaySeconds: 10);

                                  if (backupService.lastError != null &&
                                      context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(backupService.lastError!),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } else if (success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Backup scheduled! It will run in 10 seconds.'),
                                        backgroundColor: Colors.blue,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: const Text(
                              'Schedule Backup (10s)',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),

                        // Add reliable background backup UI
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Reliable Background Backup',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Continues even if app is closed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<bool>(
                          future: isBackupScheduled(),
                          builder: (context, snapshot) {
                            final isScheduled = snapshot.data ?? false;

                            return Column(
                              children: [
                                if (isScheduled)
                                  FutureBuilder<DateTime?>(
                                    future: getBackupScheduledTime(),
                                    builder: (context, timeSnapshot) {
                                      final scheduledTime = timeSnapshot.data;
                                      String timeText = 'Backup scheduled';

                                      if (scheduledTime != null) {
                                        final now = DateTime.now();
                                        final diff =
                                            scheduledTime.difference(now);

                                        if (diff.inSeconds > 0) {
                                          timeText =
                                              'Backup will run in ${diff.inSeconds} seconds';
                                        } else {
                                          timeText =
                                              'Backup is running in background';
                                        }
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.timer,
                                                color: Colors.orange),
                                            const SizedBox(width: 8),
                                            Text(
                                              timeText,
                                              style: const TextStyle(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.backup),
                                      label: const Text(
                                          'Schedule Reliable Backup'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: isScheduled
                                          ? null
                                          : () async {
                                              if (!backupService
                                                  .isInitialized) {
                                                await backupService
                                                    .initialize();
                                              }

                                              final success =
                                                  await backupService
                                                      .scheduleReliableBackup(
                                                          delaySeconds: 10);

                                              if (success && context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Reliable background backup scheduled for 10 seconds',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              } else if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Failed to schedule: ${backupService.lastError ?? "Unknown error"}',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }

                                              // Refresh the UI
                                              setState(() {});
                                            },
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.cancel),
                                      label: const Text('Cancel'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: !isScheduled
                                          ? null
                                          : () async {
                                              await backupService
                                                  .cancelScheduledBackups();

                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        'Scheduled backups canceled'),
                                                    backgroundColor:
                                                        Colors.orange,
                                                  ),
                                                );
                                              }

                                              // Refresh the UI
                                              setState(() {});
                                            },
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // Test JSON upload button
                        ElevatedButton(
                          onPressed: () async {
                            final backupService = Provider.of<BackupService>(
                                context,
                                listen: false);

                            try {
                              // Show progress indicator
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Creating test backup...'),
                                  duration: Duration(seconds: 1),
                                ),
                              );

                              // Ensure proper authentication
                              final isAuthenticated =
                                  await backupService.ensureAuthenticated();
                              if (!isAuthenticated) {
                                debugPrint("Need to authenticate first");

                                // Inform user about authentication
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please sign in with your Google account'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }

                                final signedIn = await backupService.signIn();
                                if (!signedIn) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Sign-in cancelled or failed'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }
                              }

                              // Create a simple test JSON
                              final Map<String, dynamic> testData = {
                                'timestamp': DateTime.now().toString(),
                                'test': 'This is a test backup',
                                'appInfo': <String, dynamic>{
                                  'name': 'ToDoneBu',
                                  'version': '1.0.0'
                                }
                              };

                              // Upload test JSON (this will also set the backup time)
                              final fileName =
                                  'todonebu_test_${DateTime.now().millisecondsSinceEpoch}.json';
                              await backupService.uploadTestJson(
                                  fileName, testData);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle,
                                            color: Colors.white),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                              'Test backup uploaded successfully'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('Test backup error: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Test backup failed: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text('Create Test Backup'),
                        ),

                        // Reauthorize button
                        ElevatedButton(
                          onPressed: () async {
                            final backupService = Provider.of<BackupService>(
                                context,
                                listen: false);

                            try {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Reauthorizing Google account...'),
                                  backgroundColor: Colors.blue,
                                ),
                              );

                              final success = await backupService.reauthorize();

                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Reauthorization successful'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Reauthorization failed: ${backupService.lastError}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              print('Reauthorization error: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Reauthorization error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: const Text('Reauthorize Google Drive'),
                        ),

                        // Backup status and progress indicators
                        if (isBackingUp) ...[
                          const SizedBox(height: 8),
                          Text(
                            backupService.statusMessage ?? 'Processing...',
                            style: const TextStyle(color: Colors.green),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: backupService.progress,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ],

                        // Last backup info and details button
                        if (hasBackup) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Last backup: ${_formatDate(backupService.lastBackupTime!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              print('Navigating to backup details');
                              Navigator.of(context)
                                  .pushNamed('/backup-details');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              child: Text(
                                'View Backup Details',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showBackupInfoDialog(
      BuildContext context, BackupService backupService) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Backup Completed'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Backup Details:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Status', 'Success'),
                _buildInfoRow(
                    'Backup Time',
                    backupService.lastBackupTime != null
                        ? _formatDate(backupService.lastBackupTime!)
                        : 'Just now'),
                _buildInfoRow('Backup Location', 'Google Drive'),
                const Divider(),
                const Text('This backup includes:'),
                const SizedBox(height: 4),
                _buildListItem('All your tasks and their details'),
                _buildListItem('Task images and attachments'),
                _buildListItem('App settings and preferences'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0, left: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
