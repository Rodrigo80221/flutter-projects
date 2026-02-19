import 'package:flutter/material.dart';

class MaguinhoChatWidget extends StatelessWidget {
  final String? textoVenda;

  const MaguinhoChatWidget({super.key, this.textoVenda});

  @override
  Widget build(BuildContext context) {
    // If there is no text/product context, we might still want to show the image 
    // or maybe hide it. The previous logic hid it if textoVenda was null.
    // However, the prompt implies replacing the chat area. 
    // If the product is shown (which is when this widget is called in totem_screen), 
    // we should probably show the image.
    
    // We'll keep the check if it was relevant for "displaying the section", 
    // but the user said "place the celular.png in that area".
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/celular.png',
          fit: BoxFit.fitWidth, // Force full width
          width: double.infinity,
        ),
      ),
    );
  }
}
