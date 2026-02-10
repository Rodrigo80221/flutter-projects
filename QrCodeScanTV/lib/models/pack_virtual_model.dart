class PackVirtual {
  final String? descricaoPack;
  final String? qtdRegra;
  final List<PackItem>? produtos;

  PackVirtual({this.descricaoPack, this.qtdRegra, this.produtos});

  factory PackVirtual.fromJson(Map<String, dynamic> json) {
    var list = json['Produtos'] as List?;
    List<PackItem> produtosList = [];

    if (list != null) {
      produtosList = list.map((i) => PackItem.fromJson(i)).toList();
    } else if (json['DESCRICAO'] != null) {
      // Handle flat structure where root contains the product
      produtosList.add(PackItem.fromJson(json));
    }

    return PackVirtual(
      descricaoPack: json['DescricaoPack'],
      qtdRegra: json['QtdRegra']?.toString(), // Ensure string if needed
      produtos: produtosList,
    );
  }
}

class PackItem {
  final String? descricao;
  final String? url;
  final String? urlEcommerce;

  PackItem({this.descricao, this.url, this.urlEcommerce});

  factory PackItem.fromJson(Map<String, dynamic> json) {
    return PackItem(
      descricao: json['DESCRICAO'],
      url: json['URL'],
      urlEcommerce: json['UrlEcommerce'],
    );
  }
}
