import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';

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
  Timer? _inactivityTimer;

  
  // State
  Product? _currentProduct;
  PackVirtual? _currentPromo;
  bool _isLoading = false;
  bool _searchFailed = false; // To track if we should show the "Not Found" error state
  int _rotationTurns = Platform.isAndroid ? 1 : 0;  // Rotate by default on Android for vertical TV setup
  bool _showLogs = false; // Hidden by default
  String _codLoja = '6';
  bool _isBarcodeScan = false; // Tracks if the last scan was an EAN-13 code

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _codLoja = prefs.getString('codLoja') ?? '6';
    });
  }
  
  // History & Logs
  final List<LogEntry> _logs = [];
  final ScrollController _logScrollController = ScrollController();
  
  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _mainFocusNode.dispose();
    _bufferCleaner?.cancel();
    _inactivityTimer?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    // Only set timer if we are displaying something (product or error)
    if (_currentProduct != null || _searchFailed) {
      _inactivityTimer = Timer(const Duration(seconds: 60), () {
        _addLog('Inatividade detectada (60s). Resetando para tela inicial.');
        setState(() {
          _currentProduct = null;
          _currentPromo = null;
          _searchFailed = false;
          _buffer.clear();
        });
      });
    }
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

    // Any interaction resets the timer (if active)
    if (_currentProduct != null || _searchFailed) {
       _resetInactivityTimer();
    }

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

    // Menu Key
    if (key == LogicalKeyboardKey.keyM || 
        key == LogicalKeyboardKey.contextMenu ||
        key.debugName == 'Menu' || 
        key.debugName == 'Settings') {
      _showSettingsMenu();
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

    // Command: Configurar Loja
    if (scannedUrl.trim().toLowerCase() == 'configurar loja') {
      _addLog('Comando: Configurar Loja');
      _showConfigDialog();
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
      _searchFailed = false; 
      _isBarcodeScan = RegExp(r'^\d+$').hasMatch(processedUrl.trim()) && processedUrl.trim().length <= 14;
    });

    try {
      String? extractedCode;
      String? codigoBalanca;
      String? codigoEtiqueta;
      String? barras;

      String trimmedUrl = processedUrl.trim();
      bool isBarcodeInput = _isBarcodeScan;
      
      if (isBarcodeInput) {
        barras = trimmedUrl;
        _addLog('Identificado como código de barras (EAN): $barras');
      }

      if (!isBarcodeInput) {
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

        if (extractedCode != null && extractedCode!.length >= 13) {
          codigoBalanca = extractedCode!.substring(0, 6);
          codigoEtiqueta = extractedCode!.substring(6, 13);
          _addLog('Parseado: Balança=$codigoBalanca, Etiqueta=$codigoEtiqueta');
        } else {
          if (extractedCode != null) {
             _addLog('Código extraído muito curto para processar: ${extractedCode!.length}', isError: true);
          }
        }
      }
      
      if (barras != null || (codigoBalanca != null && codigoEtiqueta != null)) {
        // 2. Fetch Product
        if (barras != null) {
           _addLog('Consultando Produto (Barras: $barras)...');
        } else {
           _addLog('Consultando Produto (Balança: $codigoBalanca)...');
        }

        final product = await _apiService.consultarEtiqueta(
          codigoBalanca: codigoBalanca,
          codigoEtiqueta: codigoEtiqueta,
          barras: barras,
          codLoja: _codLoja,
        );
        
        if (product != null) {
          _addLog('Produto encontrado: ${product.nome}');
          setState(() {
            _currentProduct = product;
          });
          
          // 3. Fetch Promo
          _addLog('Buscando Promoções/Pack...');
          final promo = await _apiService.consultarPackVirtual(
            codigoBalanca: codigoBalanca,
            codigoEtiqueta: codigoEtiqueta,
            barras: barras,
            codLoja: _codLoja,
          );
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
            codigoBalanca: codigoBalanca,
            codigoEtiqueta: codigoEtiqueta,
            barras: barras,
          );
           if(logSuccess) _addLog('Acesso registrado com sucesso.');
           else _addLog('Falha ao registrar acesso.', isError: true);
           
           // Start inactivity timer after successful display
           _resetInactivityTimer();
          
        } else {
           _addLog('Produto não encontrado na API.', isError: true);
           setState(() {
             _searchFailed = true;
           });
           // Start inactivity timer to go back to idle after showing error
           _resetInactivityTimer();
        }
      } else {
        _addLog('Dados insuficientes para consulta.', isError: true);
        setState(() {
           _searchFailed = true;
        });
        _resetInactivityTimer();
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

  void _showConfigDialog() {
    final TextEditingController controller = TextEditingController(text: _codLoja);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Configurar Loja'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: 'Digite o código da loja',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _mainFocusNode.requestFocus();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                controller.clear();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Limpar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final String newValue = controller.text.trim();
                if (newValue.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('codLoja', newValue);
                  setState(() {
                    _codLoja = newValue;
                  });
                  _addLog('Código da loja atualizado para: $_codLoja');
                }
                if (mounted) {
                   Navigator.of(context).pop();
                   _mainFocusNode.requestFocus();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A2D82),
                foregroundColor: Colors.white,
              ),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsMenu() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text('Opções do Sistema', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _showConfigDialog();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.storefront, color: Color(0xFF5A2D82)),
                    const SizedBox(width: 12),
                    Text('Configurar Loja', style: GoogleFonts.inter(fontSize: 16)),
                  ],
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _showLogs = !_showLogs);
                _mainFocusNode.requestFocus();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    Icon(_showLogs ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF5A2D82)),
                    const SizedBox(width: 12),
                    Text(_showLogs ? 'Esconder Logs' : 'Exibir Logs', style: GoogleFonts.inter(fontSize: 16)),
                  ],
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _rotationTurns++);
                _mainFocusNode.requestFocus();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.screen_rotation, color: Color(0xFF5A2D82)),
                    const SizedBox(width: 12),
                    Text('Girar Tela', style: GoogleFonts.inter(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _mainFocusNode.requestFocus();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Center(
                  child: Text('Fechar', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _mainFocusNode,
      onKey: _handleKey,
      autofocus: true,
      child: RotatedBox(
        quarterTurns: _rotationTurns,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF5A2D82), // Top color
                Color(0xFF3B1E5E), // Bottom color
              ],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent, 
        body: Column(
          children: [
            if (_currentProduct != null || _searchFailed || _isLoading)
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
                                  isBarcodeScan: _isBarcodeScan,
                                )
                              else
                                Container(
                                  margin: const EdgeInsets.only(left: 16, right: 16, top: 10),
                                  padding: const EdgeInsets.all(16),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFDEF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFFBC02D), width: 2, style: BorderStyle.none), // Using CustomPaint for dashed in real implementation, but solid here for simplicity or re-use PromoCard style if prefer. 
                                    // Let's use a simpler style that matches the requested "Magia em Andamento" design
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '🎩 Magia em Andamento!',
                                        style: GoogleFonts.inter(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFFB38F00),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Ops! Nenhuma promoção mágica por aqui… ainda!\nO Maguinho está preparando novas ofertas para você ✨🔥',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: const Color(0xFF856404),
                                          fontWeight: FontWeight.w600
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              // Maguinho Section
                              if (!_isBarcodeScan)
                                MaguinhoChatWidget(textoVenda: _currentProduct?.textoVenda),
                            ],
                          ),
                        )
                      : MagicState(isError: _searchFailed),
            ),
            // Footer Logs
            if (_showLogs)
              Container(
                height: (_rotationTurns.isOdd ? MediaQuery.of(context).size.width : MediaQuery.of(context).size.height) * 0.5,
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
                            'Versão: 1.0.2 | Build: 13/02/2026 11:30',
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
      ),
    );
  }
}
