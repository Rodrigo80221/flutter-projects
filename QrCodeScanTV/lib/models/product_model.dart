class Product {
  final String? nome;
  final String? img;
  final String? pesoBruto;
  final dynamic preco; // Can be String or number in JSON
  final dynamic valorVenda;
  final dynamic valorVendaPromo;
  final dynamic valorPromocao;
  final String? unidade;
  final dynamic possuiPromocao; // Can be boolean or string "true"/"false"
  final String? site;
  final String? urlEcommerce;
  final String? textoVenda;

  Product({
    this.nome,
    this.img,
    this.pesoBruto,
    this.preco,
    this.valorVenda,
    this.valorVendaPromo,
    this.valorPromocao,
    this.unidade,
    this.possuiPromocao,
    this.site,
    this.urlEcommerce,
    this.textoVenda,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      nome: json['nome'] ?? json['Descricao'] ?? 'Produto sem nome',
      img: json['img'] ?? json['URL'],
      pesoBruto: json['pesoBruto']?.toString(), // Safely convert number to String
      preco: json['preco'] ?? json['Preco'],
      valorVenda: json['ValorVenda'],
      valorVendaPromo: json['ValorVendaPromo'],
      valorPromocao: json['ValorPromocao'],
      unidade: json['Unidade'],
      possuiPromocao: json['PossuiPromocao'],
      site: json['site'],
      urlEcommerce: json['UrlEcommerce'],
      textoVenda: json['textovenda'],
    );
  }

  bool get isPromo {
    if (possuiPromocao is bool) return possuiPromocao;
    if (possuiPromocao is String) {
      return possuiPromocao.toLowerCase() == 'true';
    }
    return false;
  }
}
