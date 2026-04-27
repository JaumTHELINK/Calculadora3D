enum TipoTransacao { receita, despesa }

class CategoriaFinanceira {
  final String nome, emoji;
  final TipoTransacao tipo;
  const CategoriaFinanceira(
      {required this.nome, required this.emoji, required this.tipo});
}

const List<CategoriaFinanceira> categoriasReceita = [
  CategoriaFinanceira(
      nome: 'Venda de peça', emoji: '📦', tipo: TipoTransacao.receita),
  CategoriaFinanceira(
      nome: 'Serviço/Freelance', emoji: '🤝', tipo: TipoTransacao.receita),
  CategoriaFinanceira(
      nome: 'Revenda', emoji: '🏪', tipo: TipoTransacao.receita),
  CategoriaFinanceira(nome: 'Outros', emoji: '💰', tipo: TipoTransacao.receita),
];

const List<CategoriaFinanceira> categoriasDespesa = [
  CategoriaFinanceira(
      nome: 'Filamento', emoji: '🧵', tipo: TipoTransacao.despesa),
  CategoriaFinanceira(
      nome: 'Upgrade/Peça', emoji: '🔧', tipo: TipoTransacao.despesa),
  CategoriaFinanceira(
      nome: 'Manutenção', emoji: '🛠️', tipo: TipoTransacao.despesa),
  CategoriaFinanceira(
      nome: 'Energia elétrica', emoji: '⚡', tipo: TipoTransacao.despesa),
  CategoriaFinanceira(
      nome: 'Embalagem/Insumos', emoji: '📫', tipo: TipoTransacao.despesa),
  CategoriaFinanceira(
      nome: 'Taxa de plataforma', emoji: '🏷️', tipo: TipoTransacao.despesa),
  CategoriaFinanceira(
      nome: 'Impressora', emoji: '🖨️', tipo: TipoTransacao.despesa),
  CategoriaFinanceira(nome: 'Outros', emoji: '💸', tipo: TipoTransacao.despesa),
];

List<CategoriaFinanceira> get todasCategorias =>
    [...categoriasReceita, ...categoriasDespesa];

class VendaPedidoItem {
    final String idHistorico;
    final String nomeHistorico;
    final int quantidade;

    const VendaPedidoItem({
        required this.idHistorico,
        required this.nomeHistorico,
        required this.quantidade,
    });

    Map<String, dynamic> toJson() => {
                'idHistorico': idHistorico,
                'nomeHistorico': nomeHistorico,
                'quantidade': quantidade,
            };

    factory VendaPedidoItem.fromJson(Map<String, dynamic> j) => VendaPedidoItem(
                idHistorico: j['idHistorico'] ?? '',
                nomeHistorico: j['nomeHistorico'] ?? '',
                quantidade: ((j['quantidade'] ?? 0) as num).toInt(),
            );
}

class Transacao {
  final String id, categoria, descricao;
  final DateTime data;
  final TipoTransacao tipo;
  final double valor;
  final String? idHistorico, nomeHistorico;
  final int? quantidadePecas;
  final double? pesoFilamentoConsumidoG;
    final String? idPedido;
    final List<VendaPedidoItem> itensVenda;

  Transacao(
      {required this.id,
      required this.data,
      required this.tipo,
      required this.categoria,
      required this.valor,
      required this.descricao,
      this.idHistorico,
      this.nomeHistorico,
      this.quantidadePecas,
    this.pesoFilamentoConsumidoG,
    this.idPedido,
    this.itensVenda = const []});

  Map<String, dynamic> toJson() => {
        'id': id,
        'data': data.toIso8601String(),
        'tipo': tipo.name,
        'categoria': categoria,
        'valor': valor,
        'descricao': descricao,
        'idHistorico': idHistorico,
        'nomeHistorico': nomeHistorico,
        'quantidadePecas': quantidadePecas,
                'pesoFilamentoConsumidoG': pesoFilamentoConsumidoG,
                'idPedido': idPedido,
                'itensVenda': itensVenda.map((e) => e.toJson()).toList(),
      };

  factory Transacao.fromJson(Map<String, dynamic> j) => Transacao(
      id: j['id'] ?? '',
      data: DateTime.tryParse(j['data'] ?? '') ?? DateTime.now(),
      tipo: j['tipo'] == 'receita'
          ? TipoTransacao.receita
          : TipoTransacao.despesa,
      categoria: j['categoria'] ?? 'Outros',
      valor: (j['valor'] ?? 0.0).toDouble(),
      descricao: j['descricao'] ?? '',
      idHistorico: j['idHistorico'],
      nomeHistorico: j['nomeHistorico'],
      quantidadePecas: (j['quantidadePecas'] as num?)?.toInt(),
      pesoFilamentoConsumidoG:
          (j['pesoFilamentoConsumidoG'] as num?)?.toDouble(),
      idPedido: j['idPedido'],
      itensVenda: (j['itensVenda'] as List<dynamic>? ?? [])
          .map((e) => VendaPedidoItem.fromJson(e as Map<String, dynamic>))
          .toList());
}

class EstoqueFilamento {
  final String id;
  final DateTime dataCompra;
  String marca, material, cor;
  double pesoCompradoG, pesoUsadoG, custoTotal;

  EstoqueFilamento(
      {required this.id,
      required this.dataCompra,
      required this.marca,
      required this.material,
      required this.cor,
      required this.pesoCompradoG,
      required this.custoTotal,
      this.pesoUsadoG = 0.0});

  double get pesoRestanteG =>
      (pesoCompradoG - pesoUsadoG).clamp(0, pesoCompradoG);
  double get percentualUsado =>
      pesoCompradoG > 0 ? (pesoUsadoG / pesoCompradoG).clamp(0, 1) : 0;
  double get custoPorG => pesoCompradoG > 0 ? custoTotal / pesoCompradoG : 0;
  bool get esgotado => pesoRestanteG <= 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dataCompra': dataCompra.toIso8601String(),
        'marca': marca,
        'material': material,
        'cor': cor,
        'pesoCompradoG': pesoCompradoG,
        'pesoUsadoG': pesoUsadoG,
        'custoTotal': custoTotal
      };

  factory EstoqueFilamento.fromJson(Map<String, dynamic> j) => EstoqueFilamento(
      id: j['id'] ?? '',
      dataCompra: DateTime.tryParse(j['dataCompra'] ?? '') ?? DateTime.now(),
      marca: j['marca'] ?? '',
      material: j['material'] ?? 'PLA',
      cor: j['cor'] ?? '',
      pesoCompradoG: (j['pesoCompradoG'] ?? 1000.0).toDouble(),
      pesoUsadoG: (j['pesoUsadoG'] ?? 0.0).toDouble(),
      custoTotal: (j['custoTotal'] ?? 0.0).toDouble());
}

class UsoFilamento {
  final String id, idEstoque, descricao;
  final DateTime data;
  final double pesoUsadoG;
  final String? idHistorico;
  final String? idTransacao;

  UsoFilamento(
      {required this.id,
      required this.idEstoque,
      required this.data,
      required this.pesoUsadoG,
      required this.descricao,
      this.idHistorico,
      this.idTransacao});

  Map<String, dynamic> toJson() => {
        'id': id,
        'idEstoque': idEstoque,
        'data': data.toIso8601String(),
        'pesoUsadoG': pesoUsadoG,
        'descricao': descricao,
        'idHistorico': idHistorico,
        'idTransacao': idTransacao
      };

  factory UsoFilamento.fromJson(Map<String, dynamic> j) => UsoFilamento(
      id: j['id'] ?? '',
      idEstoque: j['idEstoque'] ?? '',
      data: DateTime.tryParse(j['data'] ?? '') ?? DateTime.now(),
      pesoUsadoG: (j['pesoUsadoG'] ?? 0.0).toDouble(),
      descricao: j['descricao'] ?? '',
      idHistorico: j['idHistorico'],
      idTransacao: j['idTransacao']);
}

class EstoqueMaterialExtra {
  final String id;
  final DateTime dataCadastro;
  String nome;
  int quantidadeComprada;
  int quantidadeUsada;
  double valorUnitario;

  EstoqueMaterialExtra(
      {required this.id,
      required this.dataCadastro,
      required this.nome,
      required this.quantidadeComprada,
      required this.valorUnitario,
      this.quantidadeUsada = 0});

  int get quantidadeRestante =>
      (quantidadeComprada - quantidadeUsada).clamp(0, quantidadeComprada);
  double get percentualUsado => quantidadeComprada > 0
      ? (quantidadeUsada / quantidadeComprada).clamp(0, 1)
      : 0;
  bool get esgotado => quantidadeRestante <= 0;
  double get custoTotal => valorUnitario * quantidadeComprada;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dataCadastro': dataCadastro.toIso8601String(),
        'nome': nome,
        'quantidadeComprada': quantidadeComprada,
        'quantidadeUsada': quantidadeUsada,
        'valorUnitario': valorUnitario,
      };

  factory EstoqueMaterialExtra.fromJson(Map<String, dynamic> j) =>
      EstoqueMaterialExtra(
        id: j['id'] ?? '',
        dataCadastro:
            DateTime.tryParse(j['dataCadastro'] ?? '') ?? DateTime.now(),
        nome: j['nome'] ?? '',
        quantidadeComprada: ((j['quantidadeComprada'] ?? 0) as num).toInt(),
        quantidadeUsada: ((j['quantidadeUsada'] ?? 0) as num).toInt(),
        valorUnitario: (j['valorUnitario'] ?? 0.0).toDouble(),
      );
}

class UsoMaterialExtra {
  final String id;
  final String idEstoqueMaterialExtra;
  final DateTime data;
  final int quantidadeUsada;
  final String descricao;
  final String? idHistorico;
  final String? idTransacao;

  UsoMaterialExtra(
      {required this.id,
      required this.idEstoqueMaterialExtra,
      required this.data,
      required this.quantidadeUsada,
      required this.descricao,
      this.idHistorico,
      this.idTransacao});

  Map<String, dynamic> toJson() => {
        'id': id,
        'idEstoqueMaterialExtra': idEstoqueMaterialExtra,
        'data': data.toIso8601String(),
        'quantidadeUsada': quantidadeUsada,
        'descricao': descricao,
        'idHistorico': idHistorico,
        'idTransacao': idTransacao,
      };

  factory UsoMaterialExtra.fromJson(Map<String, dynamic> j) => UsoMaterialExtra(
        id: j['id'] ?? '',
        idEstoqueMaterialExtra: j['idEstoqueMaterialExtra'] ?? '',
        data: DateTime.tryParse(j['data'] ?? '') ?? DateTime.now(),
        quantidadeUsada: ((j['quantidadeUsada'] ?? 0) as num).toInt(),
        descricao: j['descricao'] ?? '',
        idHistorico: j['idHistorico'],
        idTransacao: j['idTransacao'],
      );
}
