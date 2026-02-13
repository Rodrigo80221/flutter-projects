import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MaguinhoChatWidget extends StatefulWidget {
  final String? textoVenda;

  const MaguinhoChatWidget({super.key, this.textoVenda});

  @override
  State<MaguinhoChatWidget> createState() => _MaguinhoChatWidgetState();
}

class _MaguinhoChatWidgetState extends State<MaguinhoChatWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      print("Initializing video: assets/videos/maguinho-2p3.mp4");
      // Try to load the asset video
      _controller = VideoPlayerController.asset('assets/videos/maguinho-2p3.mp4');
      
      await _controller.initialize();
      // Ensure looping and muted autoplay
      await _controller.setLooping(true);
      await _controller.setVolume(0.0);
      await _controller.play();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (error) {
      print('Video initialization error: $error');
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro vídeo: $error';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _processText(String text) {
     // Force double newlines for Markdown paragraph breaks, as single newlines are often ignored.
     // Also replacing standard windows CRLF if present just in case.
     return text.replaceAll(RegExp(r'\r?\n'), '\n\n');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.textoVenda == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5DC), // Beige/Cream background from screenshot
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            color: const Color(0xFFC4121A), // Darker red header
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Aponte a câmera do Celular para o QR Code deste produto.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'E receba dicas exclusivas do Maguinho.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

              ],
            ),
          ),
          
          // Video + Chat Bubble Stack
          _isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video Background
                      VideoPlayer(_controller),

                      // Text Bubble Overlay
                      Positioned(
                        top: 20,
                        left: 20,
                        width: 260, // Fixed width as requested, pushing Maguinho
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.textoVenda != null)
                                MarkdownBody(
                                  data: _processText(widget.textoVenda!),
                                  styleSheet: MarkdownStyleSheet(
                                    p: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF333333),
                                      height: 1.2,
                                    ),
                                    strong: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF333333),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quer uma receita mágica? ',
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: const Color(0xFF2D3748), fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'É só me perguntar! ✨ 👇',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFE30613), // Supermago Red
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  height: 300,
                  child: Container(
                    color: const Color(0xFFF3E5DC),
                    child: Center(
                      child: _errorMessage != null
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            )
                          : const CircularProgressIndicator(),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
