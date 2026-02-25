import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  String _appVersion = '...';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
        _codLoja = prefs.getString('codLoja') ?? '6';
      });
    }
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
      final Stopwatch stopwatchTotal = Stopwatch()..start();
      
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

        final Stopwatch stopwatchProduto = Stopwatch()..start();
        final product = await _apiService.consultarEtiqueta(
          codigoBalanca: codigoBalanca,
          codigoEtiqueta: codigoEtiqueta,
          barras: barras,
          codLoja: _codLoja,
        );
        stopwatchProduto.stop();
        
        if (product != null) {
          _addLog('=> Produto carregado em ${stopwatchProduto.elapsedMilliseconds}ms');
          _addLog('Produto encontrado: ${product.nome}');
          setState(() {
            _currentProduct = product;
            _isLoading = false; // Release the loading screen immediately!
          });
          
          // Start inactivity timer after successful product display
          _resetInactivityTimer();

          // 3. Fetch Promo (Asynchronous, won't block the UI!)
          _addLog('Buscando Promoções/Pack em segundo plano...');
          final Stopwatch stopwatchPromo = Stopwatch()..start();
          _apiService.consultarPackVirtual(
            codigoBalanca: codigoBalanca,
            codigoEtiqueta: codigoEtiqueta,
            barras: barras,
            codLoja: _codLoja,
          ).then((promo) {
             stopwatchPromo.stop();
             if (promo != null) {
                if (mounted) {
                  _addLog('=> Promoção carregada em ${stopwatchPromo.elapsedMilliseconds}ms');
                  _addLog('Promoção encontrada: ${promo.descricaoPack}');
                  setState(() {
                    _currentPromo = promo;
                  });
                }
             } else {
               _addLog('Nenhuma promoção ativa (${stopwatchPromo.elapsedMilliseconds}ms).');
             }
          }).catchError((e) {
             _addLog('Erro ao buscar promoção: $e', isError: true);
          });
          
          // 4. Log Access (Asynchronous Fire-and-Forget)
          _addLog('Registrando acesso na API em segundo plano...');
          final Stopwatch stopwatchLog = Stopwatch()..start();
          _apiService.gravarDadosAcesso(
            codigoBalanca: codigoBalanca,
            codigoEtiqueta: codigoEtiqueta,
            barras: barras,
          ).then((logSuccess) {
             stopwatchLog.stop();
             if(logSuccess) _addLog('=> Acesso registrado com sucesso (${stopwatchLog.elapsedMilliseconds}ms).');
             else _addLog('Falha ao registrar acesso (${stopwatchLog.elapsedMilliseconds}ms).', isError: true);
          }).catchError((e) {
             _addLog('Erro ao registrar acesso: $e', isError: true);
          });
          
          stopwatchTotal.stop();
          _addLog('--- Produto na Tela: Fluxo Principal concluído em ${stopwatchTotal.elapsedMilliseconds}ms ---');
          
        } else {
           stopwatchTotal.stop();
           _addLog('=> Falha na busca após ${stopwatchProduto.elapsedMilliseconds}ms');
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

  void _checkForUpdates() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _withRotatedShortcuts(
          RotatedBox(
            quarterTurns: _rotationTurns,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFE30613)),
              const SizedBox(height: 16),
              const Text('Buscando atualizações...'),
            ],
          ),
          ),
          ),
        );
      },
    );

    try {
      final dio = Dio();
      final response = await dio.get('https://fluxo.telecon.cloud/webhook/atualizacao-maguinho');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = (response.data is String) ? jsonDecode(response.data) : response.data;
        final String versaoAtual = data['versao_atual']?.toString() ?? '';
        final String urlDownload = data['url_download']?.toString() ?? '';

        final packageInfo = await PackageInfo.fromPlatform();
        final String myVersion = packageInfo.version;

        bool isMaior = false;
        try {
          List<int> vHttp = versaoAtual.split('.').map((e) => int.tryParse(e) ?? 0).toList();
          List<int> vLocal = myVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
          for (int i = 0; i < 3; i++) {
             int remote = vHttp.length > i ? vHttp[i] : 0;
             int local = vLocal.length > i ? vLocal[i] : 0;
             if (remote > local) { isMaior = true; break; }
             if (remote < local) { break; }
          }
        } catch(e) {
          // Fallback comparison
        }

        if (mounted) Navigator.of(context).pop(); // dismiss loading dialog

        if (!isMaior) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('O sistema já está na versão mais recente.'), backgroundColor: Colors.green),
            );
          }
          return;
        }

        // Is greater! Show progress dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) {
              return _withRotatedShortcuts(
                RotatedBox(
                  quarterTurns: _rotationTurns,
                child: UpdateProgressDialog(url: urlDownload)
              ),
              );
            }
          );
        }
      } else {
        throw Exception('Resposta inválida do servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // dismiss loading dialog
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Falha ao buscar atualização: $e'), backgroundColor: Colors.red),
         );
      }
    }
  }

  void _showConfigDialog() {
    final TextEditingController controller = TextEditingController(text: _codLoja);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _withRotatedShortcuts(
          RotatedBox(
            quarterTurns: _rotationTurns,
          child: AlertDialog(
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
        ),
        ),
        );
      },
    );
  }

  void _showManualScanDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _withRotatedShortcuts(
          RotatedBox(
            quarterTurns: _rotationTurns,
            child: AlertDialog(
              title: const Text('Simular Leitura'),
            content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Digite o EAN ou Cole a URL',
            ),
            autofocus: true,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                 Navigator.of(context).pop();
                 _processScan(value);
              }
            },
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
            ElevatedButton(
              onPressed: () {
                final String newValue = controller.text.trim();
                if (newValue.isNotEmpty) {
                   if (mounted) {
                     Navigator.of(context).pop();
                     _processScan(newValue);
                   }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A2D82),
                foregroundColor: Colors.white,
              ),
              child: const Text('Pesquisar'),
            ),
          ],
        ),
        ),
        );
      }
    );
  }

  void _showSettingsMenu() {
    showDialog(
      context: context,
      builder: (context) {
        return _withRotatedShortcuts(
          RotatedBox(
            quarterTurns: _rotationTurns,
          child: SimpleDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Opções do Sistema', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Versão $_appVersion', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
            ],
          ),
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
                _showManualScanDialog();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: Color(0xFF5A2D82)),
                    const SizedBox(width: 12),
                    Text('Simular Leitura', style: GoogleFonts.inter(fontSize: 16)),
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
                _checkForUpdates();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.system_update, color: Color(0xFF5A2D82)),
                    const SizedBox(width: 12),
                    Text('Atualizar Sistema', style: GoogleFonts.inter(fontSize: 16)),
                  ],
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _currentProduct = null;
                  _currentPromo = null;
                  _searchFailed = false;
                  _buffer.clear();
                });
                _mainFocusNode.requestFocus();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.home, color: Color(0xFF5A2D82)),
                    const SizedBox(width: 12),
                    Text('Voltar ao Início', style: GoogleFonts.inter(fontSize: 16)),
                  ],
                ),
              ),
            ),
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
        ),
        ),
        );
      }
    );
  }

  Widget _withRotatedShortcuts(Widget child) {
    if (_rotationTurns % 4 == 0) return child;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _mainFocusNode,
      onKey: _handleKey,
      autofocus: true,
      child: _withRotatedShortcuts(
        RotatedBox(
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
                          Text(
                            'Histórico e Logs do Sistema:',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[800]),
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
      ),
    );
  }
}

class UpdateProgressDialog extends StatefulWidget {
  final String url;
  const UpdateProgressDialog({super.key, required this.url});

  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  double _progress = 0;
  String _status = "Iniciando download...";
  bool _error = false;
  
  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/app_atualizacao.apk';

      await Dio().download(
        widget.url, 
        filePath,
        onReceiveProgress: (rec, total) {
          if (total != -1 && mounted) {
             setState(() {
               _progress = rec / total;
               _status = "Baixando: ${(_progress * 100).toStringAsFixed(0)}%";
             });
          }
        }
      );

      if (mounted) {
        setState(() {
           _status = "Instalando a atualização...";
           _progress = 1.0;
        });
      }

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && mounted) {
         setState(() {
            _error = true;
            _status = "Erro ao executar o instalador:\n${result.message}";
         });
      }
    } catch(e) {
      if (mounted) {
        setState(() {
           _error = true;
           _status = "Erro no download: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
      return AlertDialog(
          title: Text(_error ? 'Falha na Atualização' : 'Atualizando Sistema', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               if (!_error) LinearProgressIndicator(value: _progress <= 0 ? null : _progress, color: const Color(0xFF5A2D82)),
               const SizedBox(height: 16),
               Text(_status, textAlign: TextAlign.center, style: GoogleFonts.inter()),
             ]
          ),
          actions: [
             if (_error)
               TextButton(
                  onPressed: () => Navigator.pop(context), 
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  child: const Text('Fechar')
               )
          ]
      );
  }
}

