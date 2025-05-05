import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'AuthService.dart';
import 'BackupService.dart';

class HomeScreen2 extends StatelessWidget {
  const HomeScreen2({super.key});

  @override
  Widget build(BuildContext context) {
    final backupService = Provider.of<BackupService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Drive Backup')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!backupService.isSignedIn)
                ElevatedButton(
                  onPressed: () async {
                    final authService = AuthService();
                    final user = await authService.signInWithGoogle();
                    if (user != null) {
                      final driveApi = await authService.getDriveApi();
                    }
                    // await backupService.signIn();
                    // await backupService.initialize();
                  },
                  child: const Text('Sign In with Google'),
                ),
              if (backupService.isSignedIn) ...[
                Text(
                  'Backup Status',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                if (backupService.lastBackupTime != null)
                  Text('Last backup: ${backupService.lastBackupTime}'),
                const SizedBox(height: 20),
                if (backupService.isBackingUp) ...[
                  LinearProgressIndicator(value: backupService.backupProgress),
                  const SizedBox(height: 10),
                  Text(
                      '${(backupService.backupProgress * 100).toStringAsFixed(1)}% complete'),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: backupService.isBackingUp
                      ? null
                      : () => backupService.performBackup(),
                  child: const Text('Perform Backup'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: backupService.isBackingUp
                      ? null
                      : () => backupService.restoreFromBackup(),
                  child: const Text('Restore Backup'),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => backupService.signOut(),
                  child: const Text('Sign Out'),
                ),
              ],
              if (backupService.lastError != null) ...[
                const SizedBox(height: 20),
                Text(
                  backupService.lastError!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
