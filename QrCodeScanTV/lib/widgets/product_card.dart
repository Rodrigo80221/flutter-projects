import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    // Formatting currency
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    
    // Safe parsing helper
    double? parsePrice(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        String clean = value.replaceAll('R\$', '').trim();
        // If it uses comma as decimal separator (PT-BR format), replace with dot
        // But if it's already dot-based (e.g. "88.46"), keep it.
        // Heuristic: if contains ',' and '.', assume standard formatting?
        // Let's just try to standardize. 
        if (clean.contains(',')) {
           clean = clean.replaceAll('.', '').replaceAll(',', '.');
        }
        return double.tryParse(clean);
      }
      return null;
    }

    double? preco = parsePrice(product.preco); // Original Total Price (14.28)
    double? valorPromo = parsePrice(product.valorPromocao); // Unit Promo Price (29.99/kg)
    double? valorVendaPromo = parsePrice(product.valorVendaPromo); // Promo Total Price (12.24)
    double? valorVenda = parsePrice(product.valorVenda); // Unit Normal Price (34.99/kg)

    bool isPromo = product.isPromo;

    // Determine what to display for Unit Price (R$/Kg)
    String unitPriceDisplay;
    if (isPromo && valorPromo != null) {
      unitPriceDisplay = currencyFormatter.format(valorPromo);
    } else {
      unitPriceDisplay = valorVenda != null ? currencyFormatter.format(valorVenda) : (product.valorVenda?.toString() ?? '-');
    }

    // Determine Main Display Price (The Big Number)
    String mainPriceDisplay;
    // Determine "From" Price (Strikethrough)
    String? fromPriceDisplay;

    if (isPromo && valorVendaPromo != null) {
       mainPriceDisplay = currencyFormatter.format(valorVendaPromo);
       fromPriceDisplay = preco != null ? currencyFormatter.format(preco) : null;
    } else {
       mainPriceDisplay = preco != null ? currencyFormatter.format(preco) : 'R\$ --,--';
       fromPriceDisplay = null;
    }

    // Weight formatting
    String peso = product.pesoBruto ?? '-';
    if (!peso.toLowerCase().contains('kg')) {
      peso += ' Kg';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              product.img ?? '',
              width: 250,
              height: 250,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 250,
                height: 250,
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 30),
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  product.nome?.toUpperCase() ?? 'PRODUTO DESCONHECIDO',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2D3748),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Peso Bruto: ',
                      style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[600]),
                    ),
                    Text(
                      peso,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(width: 20),
                    if (product.unidade != null) ...[
                       Text(
                        'R\$/ ${product.unidade}: ',
                        style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[600]),
                      ),
                       Text(
                        unitPriceDisplay,
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 24),
                if (isPromo && fromPriceDisplay != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('De ', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600])),
                          Text(
                            fromPriceDisplay,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.grey[500],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Text(' por', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600])),
                        ],
                      ),
                      Text(
                        mainPriceDisplay,
                        style: GoogleFonts.inter(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF28A745), // Green for promo
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        'Preço Total:',
                        style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
                      ),
                      Text(
                        mainPriceDisplay,
                        style: GoogleFonts.inter(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          // If regular price, use red if matches Supermago style, or dark grey
                          color: const Color(0xFFE30613), 
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
