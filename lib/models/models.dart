class Produto {
  final String id;
  final String nome;
  final String? descricao;
  final double valorCusto;
  final double valorVenda;
  final double? valorVendaPromocional;
  final String? imagemUrl;
  final String? categoria;
  final String? tipoProduto;
  final bool ativo;
  final bool lancamento;
  final int quantidadeMinima;
  final int? quantidadeMaxima;

  Produto({
    required this.id,
    required this.nome,
    this.descricao,
    required this.valorCusto,
    required this.valorVenda,
    this.valorVendaPromocional,
    this.imagemUrl,
    this.categoria,
    this.tipoProduto,
    this.ativo = true,
    this.lancamento = false,
    this.quantidadeMinima = 1,
    this.quantidadeMaxima,
  });

  double get precoExibicao {
    if (valorVendaPromocional != null && valorVendaPromocional! > 0) {
      return valorVendaPromocional!;
    }
    return valorVenda;
  }

  factory Produto.fromJson(Map<String, dynamic> json) {
    String? foto = json['foto']?.toString();
    if (foto != null && foto.isNotEmpty && !foto.startsWith('http')) {
      foto = 'https://greenlinepremium.blob.core.windows.net/produtos/$foto';
    }

    return Produto(
      id: (json['idProduto'] ?? json['id'] ?? 0).toString(),
      nome: json['nomeProduto']?.toString() ?? json['nome']?.toString() ?? 'Produto',
      descricao: json['resumo']?.toString() ??
          json['descricaoHtml']?.toString() ??
          json['descricao']?.toString() ??
          json['observacao']?.toString(),
      valorCusto: _parseDouble(json['valorCusto']),
      valorVenda: _parseDouble(json['valorVenda']),
      valorVendaPromocional: json['valorVendaPromocional'] != null
          ? _parseDouble(json['valorVendaPromocional'])
          : null,
      imagemUrl: foto,
      categoria: json['categoria']?.toString(),
      tipoProduto: json['tipoProduto']?.toString(),
      ativo: json['ativo'] as bool? ?? true,
      lancamento: json['lancamento'] as bool? ?? false,
      quantidadeMinima: (json['quantidadeMinimaVenda'] ?? 1) as int? ?? 1,
      quantidadeMaxima: json['quantidadeMaximaVenda'] as int?,
    );
  }
}

class Pedido {
  final String id;
  final String? numeroPedido;
  final DateTime? dataPedido;
  final DateTime? dataPrevisaoEntrega;
  final String status;
  final String? formaPagamento;
  final String? tipoEntrega;
  final double valorTotal;
  final double valorPedido;
  final double valorFrete;
  final double valorDesconto;
  final int quantidadeParcelas;
  final String? observacao;
  final String? codigoRastreamento;
  final String? linkPagamento;
  final List<ItemPedido> itens;

  Pedido({
    required this.id,
    this.numeroPedido,
    this.dataPedido,
    this.dataPrevisaoEntrega,
    required this.status,
    this.formaPagamento,
    this.tipoEntrega,
    required this.valorTotal,
    this.valorPedido = 0,
    this.valorFrete = 0,
    this.valorDesconto = 0,
    this.quantidadeParcelas = 1,
    this.observacao,
    this.codigoRastreamento,
    this.linkPagamento,
    required this.itens,
  });

  factory Pedido.fromJson(Map<String, dynamic> json) {
    final itensRaw = json['itens'];
    final itens = itensRaw is List
        ? itensRaw
            .whereType<Map>()
            .map((item) => ItemPedido.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <ItemPedido>[];

    final valorTotal = _parseDouble(
      json['valorTotal'] ?? json['valorPedido'] ?? json['total'] ?? json['valor'],
    );
    final valorPedido = _parseDouble(json['valorPedido'] ?? json['valorTotal']);

    return Pedido(
      id: (json['idPedido'] ?? json['id'] ?? 0).toString(),
      numeroPedido: (json['numeroPedido'] ?? json['numero'] ?? json['idPedido'])?.toString(),
      dataPedido: _parseDate(
        json['dataPedido'] ?? json['dataCadastro'] ?? json['createdAt'],
      ),
      dataPrevisaoEntrega: _parseDate(
        json['dataPrevisaoEntrega'] ?? json['dataEntrega'],
      ),
      status: json['statusPedido']?.toString() ?? json['status']?.toString() ?? 'Desconhecido',
      formaPagamento: json['formaPagamento']?.toString(),
      tipoEntrega: json['tipoEntrega']?.toString() ??
          json['metodoEntrega']?.toString() ??
          json['formaEntrega']?.toString(),
      valorTotal: valorTotal,
      valorPedido: valorPedido,
      valorFrete: _parseDouble(json['valorFrete']),
      valorDesconto: _parseDouble(json['valorDesconto']),
      quantidadeParcelas: (json['quantidadeParcelas'] ?? 1) as int? ?? 1,
      observacao: json['observacao']?.toString(),
      codigoRastreamento: json['codigoRastreamento']?.toString(),
      linkPagamento: json['linkPagamento']?.toString(),
      itens: itens,
    );
  }
}

class ItemPedido {
  final String nomeProduto;
  final String? fotoProduto;
  final int quantidade;
  final double valorUnitario;
  final double subtotal;

  ItemPedido({
    required this.nomeProduto,
    this.fotoProduto,
    required this.quantidade,
    required this.valorUnitario,
    required this.subtotal,
  });

  factory ItemPedido.fromJson(Map<String, dynamic> json) {
    final quantidade = (json['quantidade'] ?? json['qtd'] ?? 1) as int? ?? 1;
    final valorUnitario = _parseDouble(
      json['valorUnitario'] ?? json['valor'] ?? json['preco'] ?? 0,
    );
    final subtotal = _parseDouble(json['subtotal']) > 0
        ? _parseDouble(json['subtotal'])
        : valorUnitario * quantidade;

    String? foto = json['fotoProduto']?.toString();
    if (foto != null && foto.isNotEmpty && !foto.startsWith('http')) {
      foto = 'https://greenlinepremium.blob.core.windows.net/produtos/$foto';
    }

    return ItemPedido(
      nomeProduto: json['descricaoProduto']?.toString() ??
          json['nomeProduto']?.toString() ??
          json['produto']?.toString() ??
          'Produto',
      fotoProduto: foto,
      quantidade: quantidade,
      valorUnitario: valorUnitario,
      subtotal: subtotal,
    );
  }
}

class Revendedor {
  final String id;
  final String nome;
  final String email;
  final String? celular;
  final String? graduacao;
  final String? cpfCnpj;
  final Endereco? endereco;

  Revendedor({
    required this.id,
    required this.nome,
    required this.email,
    this.celular,
    this.graduacao,
    this.cpfCnpj,
    this.endereco,
  });

  factory Revendedor.fromJson(Map<String, dynamic> json) {
    return Revendedor(
      id: (json['idRevendedor'] ?? '').toString(),
      nome: json['nome']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      celular: json['celular']?.toString(),
      graduacao: json['graduacao']?.toString(),
      cpfCnpj: json['cpfCnpj']?.toString(),
      endereco: json['endereco'] is Map<String, dynamic>
          ? Endereco.fromJson(json['endereco'] as Map<String, dynamic>)
          : null,
    );
  }

  factory Revendedor.fromJwtPayload(Map<String, dynamic> payload) {
    return Revendedor(
      id: payload['nameid']?.toString() ?? '',
      nome: payload['unique_name']?.toString() ?? '',
      email: payload['email']?.toString() ?? '',
      celular: payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/mobilephone']?.toString(),
      graduacao: payload['role']?.toString(),
    );
  }
}

class Endereco {
  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? complemento;
  final String? bairro;
  final String? cidade;
  final String? estado;

  Endereco({
    this.cep,
    this.logradouro,
    this.numero,
    this.complemento,
    this.bairro,
    this.cidade,
    this.estado,
  });

  factory Endereco.fromJson(Map<String, dynamic> json) {
    return Endereco(
      cep: json['cep']?.toString(),
      logradouro: json['logradouro']?.toString() ?? json['rua']?.toString(),
      numero: json['numero']?.toString(),
      complemento: json['complemento']?.toString(),
      bairro: json['bairro']?.toString(),
      cidade: json['cidade']?.toString() ?? json['municipio']?.toString(),
      estado: json['estado']?.toString() ?? json['uf']?.toString(),
    );
  }

  String get completo {
    final partes = <String>[];
    if (logradouro != null && logradouro!.isNotEmpty) {
      partes.add('$logradouro${numero != null && numero!.isNotEmpty ? ', $numero' : ''}');
    }
    if (bairro != null && bairro!.isNotEmpty) partes.add(bairro!);
    if (cidade != null && cidade!.isNotEmpty) {
      partes.add('$cidade${estado != null && estado!.isNotEmpty ? ' - $estado' : ''}');
    }
    if (cep != null && cep!.isNotEmpty) partes.add('CEP: $cep');
    return partes.join('\n');
  }
}

class FormaPagamento {
  final int id;
  final String descricao;

  FormaPagamento({required this.id, required this.descricao});

  factory FormaPagamento.fromJson(Map<String, dynamic> json) {
    return FormaPagamento(
      id: json['id'] as int,
      descricao: json['descricao']?.toString() ?? '',
    );
  }
}

class TipoEntrega {
  final int id;
  final String descricao;

  TipoEntrega({required this.id, required this.descricao});

  factory TipoEntrega.fromJson(Map<String, dynamic> json) {
    return TipoEntrega(
      id: json['id'] as int,
      descricao: json['descricao']?.toString() ?? '',
    );
  }
}

class ItemCarrinho {
  final String produtoId;
  final String nomeProduto;
  final double preco;
  final String? imagemUrl;
  int quantidade;

  ItemCarrinho({
    required this.produtoId,
    required this.nomeProduto,
    required this.preco,
    this.imagemUrl,
    this.quantidade = 1,
  });

  double get subtotal => preco * quantidade;

  Map<String, dynamic> toJson() {
    return {
      'produtoId': produtoId,
      'nomeProduto': nomeProduto,
      'preco': preco,
      'imagemUrl': imagemUrl,
      'quantidade': quantidade,
    };
  }

  factory ItemCarrinho.fromJson(Map<String, dynamic> json) {
    return ItemCarrinho(
      produtoId: json['produtoId']?.toString() ?? '0',
      nomeProduto: json['nomeProduto']?.toString() ?? '',
      preco: (json['preco'] as num?)?.toDouble() ?? 0.0,
      imagemUrl: json['imagemUrl']?.toString(),
      quantidade: json['quantidade'] as int? ?? 1,
    );
  }
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    final cleaned = value.replaceAll(RegExp(r'[R$\s]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }
  return 0.0;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  try {
    return DateTime.parse(value.toString());
  } catch (_) {
    return null;
  }
}
