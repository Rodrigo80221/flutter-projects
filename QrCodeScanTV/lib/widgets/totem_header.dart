import 'package:flutter/material.dart';

class TotemHeader extends StatelessWidget {
  const TotemHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF5A2D82), // Purple Scheme
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Image.asset(
          'assets/images/logo-big.png',
          height: 100, 
          errorBuilder: (context, error, stackTrace) {
            // Fallback if image not found
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(30)),
              child: const Text(
                'SUPERMAGO',
                style: TextStyle(
                  color: Color(0xFF5A2D82),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
