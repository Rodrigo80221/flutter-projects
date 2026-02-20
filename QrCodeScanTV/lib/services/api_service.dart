import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import '../models/pack_virtual_model.dart';

class ApiService {
  static const String _baseUrl = 'https://fluxo.telecon.cloud/webhook/PrevineAI';

  /// Consulta informações de uma etiqueta
  Future<Product?> consultarEtiqueta({String? codigoBalanca, String? codigoEtiqueta, String? barras, String codLoja = '6'}) async {
    try {
      final payload = barras != null 
          ? {'barras': barras, 'codLoja': int.tryParse(codLoja) ?? 6}
          : {
              'codigoBalanca': codigoBalanca,
              'codigoEtiqueta': codigoEtiqueta,
              'codLoja': int.tryParse(codLoja) ?? 6,
            };
      print('ConsultarEtiqueta Payload: $payload');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/ConsultarEtiqueta'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
           final item = data[0] as Map<String, dynamic>;
           if (item.isEmpty || (item['nome'] == null && item['Descricao'] == null)) return null;
           return Product.fromJson(item);
        } else if (data is Map<String, dynamic>) {
           if (data.isEmpty || (data['nome'] == null && data['Descricao'] == null)) return null;
           return Product.fromJson(data);
        }
      }
    } catch (e) {
      print('Erro ao consultar etiqueta: $e');
    }
    return null;
  }

  /// Consulta informações do pack virtual
  Future<PackVirtual?> consultarPackVirtual({String? codigoBalanca, String? codigoEtiqueta, String? barras, String codLoja = '6'}) async {
    try {
      final payload = barras != null 
          ? {'barras': barras, 'codLoja': int.tryParse(codLoja) ?? 6}
          : {
              'codigoBalanca': codigoBalanca,
              'codigoEtiqueta': codigoEtiqueta,
              'codLoja': int.tryParse(codLoja) ?? 6,
            };

      final response = await http.post(
        Uri.parse('$_baseUrl/ConsultarPackVirtual'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        
        // Pode retornar array ou objeto único
        if (data is List && data.isNotEmpty) {
          return PackVirtual.fromJson(data[0]);
        } else if (data is Map<String, dynamic>) {
          return PackVirtual.fromJson(data);
        }
      }
    } catch (e) {
      print('Erro ao consultar pack virtual: $e');
    }
    return null;
  }

  /// Grava log de acesso (sem GEO por enquanto no Totem)
  Future<bool> gravarDadosAcesso({
    String? codigoBalanca,
    String? codigoEtiqueta,
    String? barras,
    String? codigoSessao,
    String? ipClient,
  }) async {
    try {
      final payload = {
        'body': barras != null ? {
          'barras': barras,
          'latitude': null, // Totem é fixo geralmente
          'longitude': null,
          'accuracy': null,
          'ipClient': ipClient ?? "",
          'codigoSessao': codigoSessao ?? "",
        } : {
          'codigoBalanca': codigoBalanca,
          'codigoEtiqueta': codigoEtiqueta,
          'latitude': null, // Totem é fixo geralmente
          'longitude': null,
          'accuracy': null,
          'ipClient': ipClient ?? "",
          'codigoSessao': codigoSessao ?? "",
        }
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/gravarDadosAcesso'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Erro ao gravar log: $e');
      return false;
    }
  }
}
