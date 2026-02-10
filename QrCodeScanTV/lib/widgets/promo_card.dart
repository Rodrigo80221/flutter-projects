import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/pack_virtual_model.dart';
// Note: You'll need to use a package like 'dotted_border' or CustomPainter for dashed borders, 
// using CustomPainter here for zero dependencies
import 'dart:ui';

class PromoCard extends StatefulWidget {
  final PackVirtual promo;
  final String? currentWeight;

  const PromoCard({super.key, required this.promo, this.currentWeight});

  @override
  State<PromoCard> createState() => _PromoCardState();
}

class _PromoCardState extends State<PromoCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
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
                if (widget.promo.descricaoPack != null)
                  Text(
                    widget.promo.descricaoPack!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF856404),
                    ),
                  ),
                const SizedBox(height: 20),
                if (widget.promo.produtos != null && widget.promo.produtos!.isNotEmpty)
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: widget.promo.produtos!.map((item) {
                       return _buildPromoItem(item);
                    }).toList(),
                  ),
                
                // Warning Message
                _buildPromoWarning(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromoWarning() {
    if (widget.currentWeight == null || widget.promo.qtdRegra == null) return const SizedBox.shrink();

    try {
      // Clean and parse weights
      String cleanWeight = widget.currentWeight!.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.');
      String cleanRule = widget.promo.qtdRegra!.toString().replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.');
      
      double weight = double.tryParse(cleanWeight) ?? 0;
      double rule = double.tryParse(cleanRule) ?? 0;

      if (weight > 0 && rule > 0 && weight < rule) {
        final fmt = NumberFormat("0.000", "pt_BR");
        String weightStr = fmt.format(weight);
        String ruleStr = fmt.format(rule);

        return Container(
            margin: const EdgeInsets.only(top: 24),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            // Optional: You could add a background or border here if needed, 
            // but the design usually just shows centered text for this message.
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                // Base style (Normal dark text)
                style: GoogleFonts.inter(fontSize: 18, color: const Color(0xFF5A4A08), height: 1.4), 
                children: [
                  TextSpan(
                    text: 'Falta pouco! ',
                    style: GoogleFonts.inter(color: const Color(0xFFE30613), fontWeight: FontWeight.w900),
                  ),
                  const TextSpan(text: 'O peso atual é '),
                  TextSpan(
                    text: '$weightStr kg',
                    style: GoogleFonts.inter(color: const Color(0xFFE30613), fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '. Adicione mais itens até atingir '),
                  TextSpan(
                    text: '$ruleStr kg',
                    style: GoogleFonts.inter(color: const Color(0xFFE30613), fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' para garantir a promoção.'),
                ],
              ),
            ),
        );
      }
    } catch (e) {
      // ignore parsing errors
    }
    return const SizedBox.shrink();
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
