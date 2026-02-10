import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pack_virtual_model.dart';
// Note: You'll need to use a package like 'dotted_border' or CustomPainter for dashed borders, 
// using CustomPainter here for zero dependencies
import 'dart:ui';

class PromoCard extends StatelessWidget {
  final PackVirtual promo;

  const PromoCard({super.key, required this.promo});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: CustomPaint(
        painter: DashedBorderPainter(color: const Color(0xFFFBC02D), strokeWidth: 2, gap: 5),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDEF), // Yellowish background
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'PROMOÇÃO SURPRESA!',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFB38F00),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              if (promo.descricaoPack != null)
                Text(
                  promo.descricaoPack!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF856404),
                  ),
                ),
              const SizedBox(height: 20),
              if (promo.produtos != null && promo.produtos!.isNotEmpty)
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: promo.produtos!.map((item) {
                     return _buildPromoItem(item);
                  }).toList(),
                ),
               // TODO: implement "Falta pouco!" message based on logic later if needed
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoItem(PackItem item) {
    return Container(
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          )
        ],
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              (item.url ?? '').replaceAll('&amp;', '&').replaceAll(';', ''),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
               errorBuilder: (context, error, stackTrace) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.descricao ?? '',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5A4A08),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          )
        ],
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedBorderPainter({this.color = Colors.black, this.strokeWidth = 1.0, this.gap = 5.0});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    // Rounded rect path
    path.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(16)));

    Path dashPath = Path();
    double dashWidth = 10.0;
    
    for (PathMetric pathMetric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
