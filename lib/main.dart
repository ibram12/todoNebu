import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:todonebu/screen/wolt.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo',
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      home: MainApp(),
      // home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showWoltSheet(BuildContext context) {
    WoltModalSheet.show(
      context: context,
      modalTypeBuilder: (BuildContext context) {
        final width = MediaQuery.of(context).size.width;
        if (width < 523) {
          return WoltModalType.bottomSheet();
        } else if (width < 800) {
          return WoltModalType.dialog();
        } else {
          return WoltModalType.sideSheet();
        }
      },
      pageListBuilder: (modalContext) => [
        SliverWoltModalSheetPage(
          mainContentSliversBuilder: (context) => [
            SliverList.builder(
              itemCount: 1000,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('Wolt Sheet Index $index'),
                  onTap: () => Navigator.of(modalContext).pop(),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showRegularBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return ListView.builder(
              itemCount: 1000,
              controller: scrollController,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('Regular Sheet Index $index'),
                  onTap: () => Navigator.of(context).pop(),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modal Bottom Sheet '),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showWoltSheet(context),
                icon: const Icon(Icons.layers),
                label: const Text('Trigger Wolt'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showRegularBottomSheet(context),
                icon: const Icon(Icons.vertical_align_bottom),
                label: const Text('Trigger Regular'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
