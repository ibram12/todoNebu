import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screen/wolt.dart';
import 'screens/backup_details_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/backup_service.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize background tasks framework
  await initializeBackgroundTasks();
  debugPrint('Main: Background tasks framework initialized');

  // Create the BackupService instance and initialize immediately
  final backupService = BackupService();
  await backupService.initialize();

  // Schedule a reliable backup to run after 10 seconds
  // This will continue even if the app is closed
  await backupService.scheduleReliableBackup(delaySeconds: 10);
  debugPrint('Main: Scheduled reliable background backup to run in 10 seconds');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<BackupService>(
          create: (_) => backupService,
        ),
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ToDoneBu',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => _handleAuth(context),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/todo': (context) => const MainApp(),
        '/backup-details': (context) => const BackupDetailsScreen(),
      },
    );
  }

  Widget _handleAuth(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (authService.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (authService.isAuthenticated) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

// // Legacy code kept for reference
// class HomeScreen extends StatelessWidget {
//   const HomeScreen({super.key});

//   void _showWoltSheet(BuildContext context) {
//     WoltModalSheet.show(
//       context: context,
//       modalTypeBuilder: (BuildContext context) {
//         final width = MediaQuery.of(context).size.width;
//         if (width < 523) {
//           return WoltModalType.bottomSheet();
//         } else if (width < 800) {
//           return WoltModalType.dialog();
//         } else {
//           return WoltModalType.sideSheet();
//         }
//       },
//       pageListBuilder: (modalContext) => [
//         SliverWoltModalSheetPage(
//           mainContentSliversBuilder: (context) => [
//             SliverList.builder(
//               itemCount: 1000,
//               itemBuilder: (context, index) {
//                 return ListTile(
//                   title: Text('Wolt Sheet Index $index'),
//                   onTap: () => Navigator.of(modalContext).pop(),
//                 );
//               },
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   void _showRegularBottomSheet(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (BuildContext context) {
//         return DraggableScrollableSheet(
//           expand: false,
//           builder: (context, scrollController) {
//             return ListView.builder(
//               itemCount: 1000,
//               controller: scrollController,
//               itemBuilder: (context, index) {
//                 return ListTile(
//                   title: Text('Regular Sheet Index $index'),
//                   onTap: () => Navigator.of(context).pop(),
//                 );
//               },
//             );
//           },
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Modal Bottom Sheet '),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(24.0),
//         child: Center(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ElevatedButton.icon(
//                 onPressed: () => _showWoltSheet(context),
//                 icon: const Icon(Icons.layers),
//                 label: const Text('Trigger Wolt'),
//               ),
//               const SizedBox(height: 16),
//               ElevatedButton.icon(
//                 onPressed: () => _showRegularBottomSheet(context),
//                 icon: const Icon(Icons.vertical_align_bottom),
//                 label: const Text('Trigger Regular'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
