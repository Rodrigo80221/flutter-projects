import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:video_player/video_player.dart';

class MagicState extends StatefulWidget {
  final bool isError;
  const MagicState({super.key, this.isError = false});

  @override
  State<MagicState> createState() => _MagicStateState();
}

class _MagicStateState extends State<MagicState> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/ImagemAnimada.mp4')
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play() call.
        setState(() {
          _isInitialized = true;
        });
        _controller.setLooping(true);
        _controller.setVolume(0.0); // Mute mainly for safety/public areas
        _controller.play();
      }).catchError((error) {
        debugPrint("Error initializing video: $error");
      });
  }

  @override
  void didUpdateWidget(MagicState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isError != oldWidget.isError) {
      if (widget.isError) {
        _controller.pause();
      } else {
        _controller.play();
      }
    }
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isError) {
      // Error State
      return Center(
        child: FadeIn(
          duration: const Duration(seconds: 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_fix_high,
                  size: 100,
                  color: Colors.purple.shade300,
                ),
                const SizedBox(height: 20),
                Text(
                  "Essa embalagem sumiu do nosso estoque mágico! 🧙‍♂️",
                  style: GoogleFonts.merriweather(
                    fontSize: 28,
                    color: Colors.deepPurple,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "Tente outro produto ou fale com o Maguinho para receber dicas mágicas.",
                  style: GoogleFonts.merriweather(
                    fontSize: 20,
                    color: Colors.deepPurple.shade300,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Main Idle State: Looping Video
    return Container(
      color: const Color(0xFFE30613), // Red Header Color
      width: double.infinity,
      height: double.infinity,
      child: FadeIn(
        duration: const Duration(milliseconds: 800),
        child: Visibility(
           visible: _isInitialized,
           replacement: Image.asset(
             'assets/images/front-maguinho.png',
             fit: BoxFit.contain, // Match video behavior
             alignment: Alignment.topCenter,
             errorBuilder: (context, error, stackTrace) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
             },
           ),
           child: Align(
             alignment: Alignment.topCenter,
             child: AspectRatio(
               aspectRatio: _controller.value.aspectRatio,
               child: VideoPlayer(_controller),
             ),
           ),
        ),
      ),
    );
  }
}
