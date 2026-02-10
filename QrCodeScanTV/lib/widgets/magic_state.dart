import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class MagicState extends StatelessWidget {
  const MagicState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeIn(
        duration: const Duration(seconds: 1),
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
    );
  }
}
