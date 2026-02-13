import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb logic if needed, but mostly for Platform check
import 'dart:io'; 
import 'screens/totem_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Windows: Set window size to 540 x 960
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    
    // Default size: 540 width, 960 height
    WindowOptions windowOptions = const WindowOptions(
      size: Size(540, 960),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'TV Barcode Scanner (Totem)',
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Android/Mobile: Lock to Portrait
  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TV Barcode Scanner (Totem)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light, 
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const TotemScreen(),
    );
  }
}


