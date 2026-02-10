import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/totem_screen.dart';

void main() {
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
        brightness: Brightness.light, // Totem uses light theme (white bg)
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const TotemScreen(),
    );
  }
}


