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

class Transacao {
  final String id, categoria, descricao;
  final DateTime data;
  final TipoTransacao tipo;
  final double valor;
  final String? idHistorico, nomeHistorico;
  final int? quantidadePecas;
  final double? pesoFilamentoConsumidoG;

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
      this.pesoFilamentoConsumidoG});

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
        'pesoFilamentoConsumidoG': pesoFilamentoConsumidoG
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
          (j['pesoFilamentoConsumidoG'] as num?)?.toDouble());
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
