import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../models/product_model.dart';
import '../models/pack_virtual_model.dart';
import '../widgets/totem_header.dart';
import '../widgets/product_card.dart';
import '../widgets/promo_card.dart';
import '../widgets/magic_state.dart';

class TotemScreen extends StatefulWidget {
  const TotemScreen({super.key});

  @override
  State<TotemScreen> createState() => _TotemScreenState();
}

class _TotemScreenState extends State<TotemScreen> {
  final FocusNode _mainFocusNode = FocusNode();
  final StringBuffer _buffer = StringBuffer();
  Timer? _bufferCleaner;
  
  // State
  Product? _currentProduct;
  PackVirtual? _currentPromo;
  bool _isLoading = false;
  
  // History
  final List<String> _history = [];
  
  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _mainFocusNode.dispose();
    _bufferCleaner?.cancel();
    super.dispose();
  }

  void _handleKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final key = event.logicalKey;

    // Ignore navigation keys
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.tab) {
      return;
    }

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_buffer.isNotEmpty) {
        _processScan(_buffer.toString());
        _buffer.clear();
      }
      return;
    }

    if (event.character != null && event.character!.isNotEmpty) {
      // Filter printable characters
       if (event.character!.runes.every((r) => r >= 32)) {
         _bufferCleaner?.cancel();
         _buffer.write(event.character);
         _bufferCleaner = Timer(const Duration(seconds: 2), () {
           _buffer.clear();
         });
       }
    }
  }

  Future<void> _processScan(String scannedUrl) async {
    setState(() {
      _isLoading = true;
      _currentProduct = null;
      _currentPromo = null;
      // Add to history at the top
      _history.insert(0, scannedUrl);
      if (_history.length > 5) {
        _history.removeLast();
      }
    });

    try {
      // 1. Parse URL
      
      // Logic from JS:
      // Tenta pegar do pathname (Azure/Produção) ou do hash (Fallback/Local)
      // Procura o segmento "21" (Identificador GS1 para Serial/Código)
      
      String? codigoBalanca;
      String? codigoEtiqueta;
      
      print('Raw Scanned URL: $scannedUrl');

      String? extractedCode;
      String cleanUrl = scannedUrl.trim();

      // Priority Strategy: Manual String Split by GS1 AI Identifier "/21/"
      // This is the most robust way to handle the "11" parameter issue described.
      if (cleanUrl.contains('/21/')) {
        List<String> parts = cleanUrl.split('/21/');
        if (parts.length > 1) {
          // Take everything after the last '/21/'
          String candidate = parts.last;
          
          // Stop at '?' (Query parameters start)
          if (candidate.contains('?')) {
            candidate = candidate.split('?')[0];
          }
          
          // Stop at '&' (In case '?' was missing/swallowed but params exist)
          if (candidate.contains('&')) {
            candidate = candidate.split('&')[0];
          }

          // Stop at next '/' (If there are further path segments)
          if (candidate.contains('/')) {
            candidate = candidate.split('/')[0];
          }
          
          extractedCode = candidate;
        }
      } 
      
      // Final cleanup of extractedCode
      if (extractedCode != null) {
          // 1. Remove standard query delimiters if missed
          final badChars = RegExp(r'[?&]');
          if (extractedCode!.contains(badChars)) {
              extractedCode = extractedCode!.split(badChars)[0];
          }
          
          // 2. Remove '=' and anything after (indicates leaked parameter key)
          if (extractedCode!.contains('=')) {
              extractedCode = extractedCode!.split('=')[0];
          }
          
          // 3. Truncate to 13 digits. 
          // GS1 Logic for this project: 6 (Balance) + 7 (Label) = 13 digits.
          // If we have more (e.g. ...11), it's likely the next AI key leaking.
          if (extractedCode!.length > 13) {
             extractedCode = extractedCode!.substring(0, 13);
          }
      }
      
      print("Extracted Code Final: $extractedCode");
      
      if (extractedCode != null && extractedCode.length > 6) {
        codigoBalanca = extractedCode.substring(0, 6);
        codigoEtiqueta = extractedCode.substring(6);
      }
      
      print('Parsed: Balanca=$codigoBalanca, Etiqueta=$codigoEtiqueta');

      if (codigoBalanca != null && codigoEtiqueta != null) {
        // 2. Fetch Product
        final product = await _apiService.consultarEtiqueta(codigoBalanca, codigoEtiqueta);
        
        if (product != null) {
          setState(() {
            _currentProduct = product;
          });
          
          // 3. Fetch Promo
          final promo = await _apiService.consultarPackVirtual(codigoBalanca!, codigoEtiqueta!);
          if (promo != null) {
            setState(() {
              _currentPromo = promo;
            });
          }
          
          // 4. Log Access
           _apiService.gravarDadosAcesso(
            codigoBalanca: codigoBalanca!,
            codigoEtiqueta: codigoEtiqueta!,
            // codSessao and ipClient are skipped for now or can be added if we have a way to get them
          );
          
        } else {
           // Product not found, stay null (Magic State)
        }
      }
      
    } catch (e) {
      print('Error processing scan: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _mainFocusNode,
      onKey: _handleKey,
      autofocus: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA), // Off-white background from CSS
        body: Column(
          children: [
            const TotemHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE30613)))
                  : _currentProduct != null
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            children: [
                              const SizedBox(height: 40),
                              ProductCard(product: _currentProduct!),
                              if (_currentPromo != null) 
                                PromoCard(
                                  promo: _currentPromo!, 
                                  currentWeight: _currentProduct?.pesoBruto,
                                ),
                            ],
                          ),
                        )
                      : const MagicState(),
            ),
            // Footer History
            Container(
              width: double.infinity,
              color: Colors.grey[200],
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Histórico de Leituras:',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 5),
                  if (_history.isEmpty)
                    Text('Nenhuma leitura realizada.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey))
                  else
                    ..._history.map((url) => Text(
                          url,
                          style: GoogleFonts.sourceCodePro(fontSize: 10, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
