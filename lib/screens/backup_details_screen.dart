import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';

class BackupDetailsScreen extends StatefulWidget {
  const BackupDetailsScreen({super.key});

  @override
  State<BackupDetailsScreen> createState() => _BackupDetailsScreenState();
}

class _BackupDetailsScreenState extends State<BackupDetailsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _backupFiles = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBackupData();
  }

  Future<void> _loadBackupData() async {
    final backupService = Provider.of<BackupService>(context, listen: false);

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Make sure the service is initialized and signed in
      if (!backupService.isInitialized) {
        await backupService.initialize();
      }

      if (!backupService.isSignedIn) {
        await backupService.signIn();
      }

      if (backupService.isSignedIn) {
        // Load backup files list
        final files = await backupService.listBackupFiles();
        setState(() {
          _backupFiles = files;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Not signed in. Please sign in to view backup data.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load backup data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreBackup(String backupId) async {
    final backupService = Provider.of<BackupService>(context, listen: false);

    try {
      setState(() {
        _isLoading = true;
      });

      await backupService.restoreSpecificBackup(backupId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restored successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore backup: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBackupData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBackupData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _backupFiles.isEmpty
                  ? const Center(
                      child: Text('No backups found'),
                    )
                  : ListView.builder(
                      itemCount: _backupFiles.length,
                      itemBuilder: (context, index) {
                        final backup = _backupFiles[index];
                        final backupDate = DateTime.fromMillisecondsSinceEpoch(
                          int.parse(backup['name']
                              .toString()
                              .split('_')
                              .last
                              .split('.')
                              .first),
                        );

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.backup),
                            ),
                            title: Text('Backup ${index + 1}'),
                            subtitle: Text(
                              '${backupDate.day}/${backupDate.month}/${backupDate.year} ${backupDate.hour}:${backupDate.minute.toString().padLeft(2, '0')}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.restore),
                              onPressed: () => _restoreBackup(backup['id']),
                            ),
                            onTap: () =>
                                _showBackupDetailsDialog(context, backup),
                          ),
                        );
                      },
                    ),
    );
  }

  void _showBackupDetailsDialog(
      BuildContext context, Map<String, dynamic> backup) {
    final backupDate = DateTime.fromMillisecondsSinceEpoch(
      int.parse(backup['name'].toString().split('_').last.split('.').first),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Backup Information'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('File Name', backup['name']),
                _buildInfoRow(
                    'Size', '${(backup['size'] / 1024).toStringAsFixed(2)} KB'),
                _buildInfoRow('Created',
                    '${backupDate.day}/${backupDate.month}/${backupDate.year} ${backupDate.hour}:${backupDate.minute.toString().padLeft(2, '0')}'),
                _buildInfoRow('Location', 'Google Drive'),
                const Divider(),

                // Preview backup data button
                ElevatedButton(
                  onPressed: () =>
                      _showBackupContentsPreview(context, backup['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  child: const Text('Preview Backup Contents'),
                ),

                const Divider(),
                const Text('Actions:'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _restoreBackup(backup['id']),
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBackupContentsPreview(
      BuildContext context, String backupId) async {
    final backupService = Provider.of<BackupService>(context, listen: false);

    try {
      setState(() {
        _isLoading = true;
      });

      // Download and parse the backup
      final backupData = await backupService.downloadBackupJson(backupId);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show the contents in a dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Backup Contents'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display backup timestamp
                    Text(
                      'Backup date: ${backupData['timestamp'] ?? 'Unknown date'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    // Display error if any
                    if (backupData['error'] != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                backupData['error'].toString(),
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Divider(),

                    // Display todos
                    const Text(
                      'Tasks:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    if (backupData['todos'] != null &&
                        (backupData['todos'] as List).isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: (backupData['todos'] as List).length,
                        itemBuilder: (context, index) {
                          final todo = (backupData['todos'] as List)[index];
                          return ListTile(
                            leading: Icon(
                              todo['isDone'] != null && todo['isDone']
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: todo['isDone'] != null && todo['isDone']
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            title: Text(todo['title'] ?? 'Unnamed Task'),
                            subtitle: Text(
                                'Created: ${todo['createdAt'] ?? 'Unknown date'}'),
                            dense: true,
                          );
                        },
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('No tasks in this backup'),
                      ),
                    const Divider(),

                    // Display image count
                    if (backupData['images'] != null &&
                        (backupData['images'] as List).isNotEmpty) ...[
                      Text(
                        'Images: ${(backupData['images'] as List).length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          (backupData['images'] as List).length,
                          (index) => Chip(
                            label: Text('Image ${index + 1}'),
                            avatar: const Icon(Icons.image, size: 16),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Images: 0',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('No images in this backup'),
                    ],
                    const Divider(),

                    // Display app settings
                    const Text(
                      'App Settings:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    if (backupData['appSettings'] != null)
                      ...((backupData['appSettings'] as Map<String, dynamic>? ??
                              {})
                          .entries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text('${entry.key}: ${entry.value}'),
                            ),
                          ))
                    else
                      const Text('No settings available'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load backup contents: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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
}
