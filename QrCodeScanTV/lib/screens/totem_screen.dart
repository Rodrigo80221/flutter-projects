import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../models/product_model.dart';
import '../models/pack_virtual_model.dart';
import '../widgets/totem_header.dart';
import '../widgets/product_card.dart';
import '../widgets/promo_card.dart';
import '../widgets/magic_state.dart';
import '../widgets/maguinho_chat.dart';

class LogEntry {
  final DateTime timestamp;
  final String message;
  final bool isError;

  LogEntry(this.message, {this.isError = false}) : timestamp = DateTime.now();
  
  String get formattedTime => DateFormat('HH:mm:ss').format(timestamp);
}

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
  int _rotationTurns = 0;  // For manual screen rotation
  bool _showLogs = false; // Hidden by default
  
  // History & Logs
  final List<LogEntry> _logs = [];
  final ScrollController _logScrollController = ScrollController();
  
  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _mainFocusNode.dispose();
    _bufferCleaner?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  void _addLog(String message, {bool isError = false}) {
    setState(() {
      _logs.insert(0, LogEntry(message, isError: isError));
      // Keep only last 50 logs to avoid memory issues
      if (_logs.length > 50) {
        _logs.removeLast();
      }
    });
  }

  void _handleKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final key = event.logicalKey;

    // Manual Screen Rotation
    if (key == LogicalKeyboardKey.arrowRight) {
      _addLog('Girar tela +90°');
      setState(() => _rotationTurns++);
      return;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _addLog('Girar tela -90°');
      setState(() => _rotationTurns--);
      return;
    }

    // Ignore navigation keys
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
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

    String? charToAppend;

    // Manual mapping to fix common scanner issues (Shift state errors, missing chars)
    if (key == LogicalKeyboardKey.slash || key == LogicalKeyboardKey.numpadDivide) {
      // Force slash for slash key and numpad divide
      charToAppend = '/'; 
    } else if (key == LogicalKeyboardKey.semicolon) {
      // Bias towards colon if we are at the start of a URL
      if (event.isShiftPressed || _buffer.toString().toLowerCase().endsWith('https') || _buffer.toString().toLowerCase().endsWith('http')) {
        charToAppend = ':';
      } else {
        charToAppend = ';';
      }
    } else {
      charToAppend = event.character;
    }

    if (charToAppend != null && charToAppend.isNotEmpty) {
      // Filter printable characters
       if (charToAppend.runes.every((r) => r >= 32)) {
         _bufferCleaner?.cancel();
         _buffer.write(charToAppend);
         _bufferCleaner = Timer(const Duration(seconds: 2), () {
           if (_buffer.isNotEmpty) {
             // _addLog('Buffer limpo por timeout (incompleto): ${_buffer.toString()}', isError: true); // Optional: log timeouts
             _buffer.clear();
           }
         });
       }
    }
  }

  Future<void> _processScan(String scannedUrl) async {
    _addLog('--- Nova Leitura Iniciada ---');
    _addLog('Input Bruto: $scannedUrl');

    // Command: Rotate
    if (scannedUrl.trim().toLowerCase() == 'girar') {
      _addLog('Comando de Rotação Executado via Scanner');
      setState(() => _rotationTurns++);
      return;
    }

    // Command: Show/Hide Logs
    if (scannedUrl.trim().toLowerCase() == 'exibir logs') {
      _addLog('Comando: Exibir Logs');
      setState(() => _showLogs = true);
      return;
    }
    if (scannedUrl.trim().toLowerCase() == 'esconder logs') {
      // Intentionally not logging this significantly since they will be hidden
      setState(() => _showLogs = false);
      return;
    }

    // 1. Basic Protocol Cleanup
    String processedUrl = scannedUrl;
    // Fix common sticky-shift issue: "https?" -> "https://"
    if (processedUrl.startsWith('https?')) {
      processedUrl = processedUrl.replaceFirst('https?', 'https://');
      _addLog('Correção de Protocolo: https? -> https://');
    } else if (processedUrl.startsWith('http?')) {
      processedUrl = processedUrl.replaceFirst('http?', 'http://');
      _addLog('Correção de Protocolo: http? -> http://');
    }

    setState(() {
      _isLoading = true;
      _currentProduct = null;
      _currentPromo = null;
    });

    try {
      String? extractedCode;
      
      // Strategy A: Standard Delimiter Split (/21/)
      if (processedUrl.contains('/21/')) {
        List<String> parts = processedUrl.split('/21/');
        if (parts.length > 1) {
          String candidate = parts.last;
          if (candidate.contains('?')) candidate = candidate.split('?')[0];
          if (candidate.contains('&')) candidate = candidate.split('&')[0];
          if (candidate.contains('/')) candidate = candidate.split('/')[0];
          extractedCode = candidate;
          _addLog('Extração via /21/ sucesso: $extractedCode');
        }
      } 
      
      // Strategy B: Robust Regex Fallback
      if (extractedCode == null) {
        _addLog('Tentando extração via Regex fallback...');
        final fallbackRegex = RegExp(r'01\d{14}21([a-zA-Z0-9]+)');
        final match = fallbackRegex.firstMatch(processedUrl);
        if (match != null) {
          String candidate = match.group(1)!;
          extractedCode = candidate;
          _addLog('Extração via Regex sucesso: $extractedCode');
        } else {
           _addLog('Falha na extração de código (Regex). URL pode estar inválida.', isError: true);
        }
      }

      // Final cleanup and Validation of extractedCode
      if (extractedCode != null) {
          final badChars = RegExp(r'[?&=]');
          if (extractedCode!.contains(badChars)) {
              List<String> parts = extractedCode!.split(badChars);
              extractedCode = parts[0];
              _addLog('Cleaned metadata: $extractedCode');
          }
          
          if (extractedCode!.length > 13) {
             extractedCode = extractedCode!.substring(0, 13);
             _addLog('Truncado para 13 chars: $extractedCode');
          }
      }

      String? codigoBalanca;
      String? codigoEtiqueta;

      if (extractedCode != null && extractedCode.length >= 13) {
        codigoBalanca = extractedCode!.substring(0, 6);
        codigoEtiqueta = extractedCode!.substring(6, 13);
        _addLog('Parseado: Balança=$codigoBalanca, Etiqueta=$codigoEtiqueta');
      } else {
        if (extractedCode != null) {
           _addLog('Código extraído muito curto para processar: ${extractedCode.length}', isError: true);
        }
      }
      
      if (codigoBalanca != null && codigoEtiqueta != null) {
        // 2. Fetch Product
        _addLog('Consultando Produto (Balança: $codigoBalanca)...');
        final product = await _apiService.consultarEtiqueta(codigoBalanca, codigoEtiqueta);
        
        if (product != null) {
          _addLog('Produto encontrado: ${product.nome}');
          setState(() {
            _currentProduct = product;
          });
          
          // 3. Fetch Promo
          _addLog('Buscando Promoções/Pack...');
          final promo = await _apiService.consultarPackVirtual(codigoBalanca!, codigoEtiqueta!);
          if (promo != null) {
             _addLog('Promoção encontrada: ${promo.descricaoPack}');
            setState(() {
              _currentPromo = promo;
            });
          } else {
            _addLog('Nenhuma promoção ativa.');
          }
          
          // 4. Log Access
           _addLog('Registrando acesso na API...');
           bool logSuccess = await _apiService.gravarDadosAcesso(
            codigoBalanca: codigoBalanca!,
            codigoEtiqueta: codigoEtiqueta!,
          );
          if(logSuccess) _addLog('Acesso registrado com sucesso.');
          else _addLog('Falha ao registrar acesso.', isError: true);
          
        } else {
           _addLog('Produto não encontrado na API.', isError: true);
        }
      } else {
        _addLog('Dados insuficientes para consulta.', isError: true);
      }
      
    } catch (e, stackTrace) {
      _addLog('Erro CRÍTICO no processamento: $e', isError: true);
      debugPrintStack(label: e.toString(), stackTrace: stackTrace);
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
      child: RotatedBox(
        quarterTurns: _rotationTurns,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FA), 
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
                              const SizedBox(height: 10),
                              ProductCard(product: _currentProduct!),
                              if (_currentPromo != null) 
                                PromoCard(
                                  promo: _currentPromo!, 
                                  currentWeight: _currentProduct?.pesoBruto,
                                ),
                              
                              // Maguinho Section
                              MaguinhoChatWidget(textoVenda: _currentProduct?.textoVenda),
                            ],
                          ),
                        )
                      : const MagicState(),
            ),
            // Footer Logs
            if (_showLogs)
              Container(
                height: 120, // Fixed height for logs
              width: double.infinity,
              color: Colors.grey[200],
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Histórico e Logs do Sistema:',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                          ),
                          Text(
                            'Versão: 1.0.1 | Build: 13/02/2026 11:10 | obs: Diminuir layout',
                            style: GoogleFonts.sourceCodePro(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey[600]),
                        onPressed: () {
                           setState(() {
                             _logs.clear();
                           });
                        },
                        tooltip: "Limpar Logs",
                      )
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _logs.isEmpty
                      ? Center(child: Text('Aguardando leituras...', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)))
                      : ListView.separated(
                          controller: _logScrollController,
                          itemCount: _logs.length,
                          separatorBuilder: (c, i) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return SelectableText.rich(
                               TextSpan(
                                 children: [
                                   TextSpan(
                                     text: '[${log.formattedTime}] ',
                                     style: GoogleFonts.sourceCodePro(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.bold)
                                   ),
                                   TextSpan(
                                     text: log.message,
                                     style: GoogleFonts.sourceCodePro(
                                       fontSize: 9, 
                                       color: log.isError ? Colors.red[700] : Colors.grey[800],
                                       fontWeight: log.isError ? FontWeight.bold : FontWeight.normal
                                     )
                                   ),
                                 ]
                               )
                            );
                          },
                        ),
                  ),
                ],
              ),
            )
          ],
        ),
        ),
      ),
    );
  }
}
