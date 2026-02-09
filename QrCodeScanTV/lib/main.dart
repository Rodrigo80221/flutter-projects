import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TV Barcode Scanner',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const BarcodeScannerScreen(),
    );
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // FocusNode required for RawKeyboardListener
  final FocusNode _mainFocusNode = FocusNode();
  
  // To handle the barcode input
  String _lastScannedCode = "Aguardando leitura...";
  final StringBuffer _buffer = StringBuffer();
  final List<String> _scanHistory = [];

  // Focus for the actionable buttons/list to ensure D-Pad navigation works
  final FocusNode _listFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _mainFocusNode.dispose();
    _listFocusNode.dispose();
    super.dispose();
  }

  void _handleKey(RawKeyEvent event) {
    // Only process key down events
    if (event is! RawKeyDownEvent) return;

    final key = event.logicalKey;

    // Filter out navigation keys (D-Pad uses arrows and enter/select)
    // Note: Some scanners send 'Enter' at the end. We need to handle this carefully.
    // If the buffer is empty, Enter is likely a D-Pad action.
    // If the buffer is NOT empty, Enter is likely the end of the barcode.
    
    bool isNavigationKey = key == LogicalKeyboardKey.arrowUp ||
                           key == LogicalKeyboardKey.arrowDown ||
                           key == LogicalKeyboardKey.arrowLeft ||
                           key == LogicalKeyboardKey.arrowRight ||
                           key == LogicalKeyboardKey.tab;

    if (isNavigationKey) {
      // Do not add to buffer
      return; 
    }

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.select) {
      if (_buffer.isNotEmpty) {
        // It's a barcode completion
        _finalizeScan();
        // Prevent default action (like triggering a button) if it was a scan?
        // Returning here helps, but 'Enter' might still propagate as a submit.
        // In a real app we might want to stop propagation using Focus intent, but here we just consume logical logic.
      }
      return;
    }

    // Accumulate characters
    // Scanners usually simulate keyboard presses.
    // event.character works for printable characters on most platforms.
    if (event.character != null && event.character!.isNotEmpty) {
      // Check if it's a printable character (not a control char)
      bool isPrintable = event.character!.runes.every((r) => r >= 32);
      if (isPrintable) {
        _buffer.write(event.character);
      }
    }
  }

  void _finalizeScan() {
    setState(() {
      _lastScannedCode = _buffer.toString();
      _scanHistory.insert(0, _lastScannedCode);
      _buffer.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código Lido: $_lastScannedCode'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _mainFocusNode,
      onKey: _handleKey,
      autofocus: true, // Ensure we catch events initially
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leitor de Código de Barras (Modo HID)'),
        ),
        body: Row(
          children: [
            // Left Panel: Navigation/Menu (D-Pad accessible)
            NavigationRail(
              selectedIndex: 0,
              onDestinationSelected: (idx) {},
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.qr_code_scanner),
                  label: Text('Scan'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings),
                  label: Text('Config'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // Main Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Aponte o leitor e escaneie',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
                    ),
                    const SizedBox(height: 40),
                    // Display Area
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                      ),
                      child: Text(
                        _lastScannedCode,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Courier', // Monospace for codes
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Histórico:', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ),
                    const SizedBox(height: 10),
                    // List of history (Focusable for D-Pad)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _scanHistory.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(_scanHistory[index]),
                            focusNode: index == 0 ? _listFocusNode : null, // Give initial focus to first item or list
                            onTap: () {
                              // Action on click/enter
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
