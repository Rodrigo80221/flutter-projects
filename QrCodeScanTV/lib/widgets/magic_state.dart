import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class MagicState extends StatelessWidget {
  final bool isError;
  const MagicState({super.key, this.isError = false});

  @override
  Widget build(BuildContext context) {
    if (!isError) {
      return SizedBox.expand(
        child: FadeIn(
          duration: const Duration(milliseconds: 800),
          child: Image.asset(
            'assets/images/front-maguinho.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
               return const Center(child: Icon(Icons.qr_code_scanner, size: 100, color: Color(0xFFE30613)));
            },
          ),
        ),
      );
    }

    return Center(
      child: FadeIn(
        duration: const Duration(seconds: 1),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isError ? Icons.auto_fix_high : Icons.qr_code_scanner,
                  size: 100,
                  color: isError ? Colors.purple.shade300 : const Color(0xFFE30613), // Red or Purple
                ),
                const SizedBox(height: 20),
                Text(
                  isError 
                   ? "Essa embalagem sumiu do nosso estoque mágico! 🧙‍♂️"
                   : "Descubra a Oferta Mágica! 🪄",
                  style: GoogleFonts.merriweather(
                    fontSize: 28,
                    color: isError ? Colors.deepPurple : const Color(0xFFE30613),
                    fontStyle: isError ? FontStyle.italic : FontStyle.normal,
                    fontWeight: isError ? FontWeight.normal : FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  isError 
                    ? "Tente outro produto ou fale com o Maguinho para receber dicas mágicas."
                    : "Escaneie o QR Code da etiqueta de peso e veja se o Maguinho liberou um preço especial.",
                  style: GoogleFonts.merriweather(
                    fontSize: 20,
                    color: isError ? Colors.deepPurple.shade300 : Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
        ),
      ),
    );
  }
}
