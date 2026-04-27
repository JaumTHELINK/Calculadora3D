class PedidoLinhaItem {
  final String id;
  String? idHistorico;
  String nomeItemSalvo;
  int quantidade;

  PedidoLinhaItem({
    required this.id,
    this.idHistorico,
    required this.nomeItemSalvo,
    required this.quantidade,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'idHistorico': idHistorico,
        'nomeItemSalvo': nomeItemSalvo,
        'quantidade': quantidade,
      };

  factory PedidoLinhaItem.fromJson(Map<String, dynamic> j) => PedidoLinhaItem(
        id: j['id'] ?? '',
        idHistorico: j['idHistorico'],
        nomeItemSalvo: j['nomeItemSalvo'] ?? 'Sem item',
        quantidade: ((j['quantidade'] ?? 1) as num).toInt(),
      );
}

class PedidoItem {
  final String id;
  final DateTime data;
  String nomeCliente;
  List<PedidoLinhaItem> itens;
  double valorCobrado;
  double valorPago;
  String observacoes;
  String? idTransacaoReceita;

  PedidoItem({
    required this.id,
    required this.data,
    required this.nomeCliente,
    this.itens = const [],
    required this.valorCobrado,
    this.valorPago = 0.0,
    this.observacoes = '',
    this.idTransacaoReceita,
  });

  String? get idHistorico => itens.isEmpty ? null : itens.first.idHistorico;

  String get nomeItemSalvo => itens.isEmpty
      ? 'Sem item'
      : itens.map((e) => e.nomeItemSalvo).join(' + ');

  int get quantidade => itens.fold(0, (s, e) => s + e.quantidade);

  double get valorRestante => (valorCobrado - valorPago).clamp(0, valorCobrado);

  bool get pagoTotal => valorRestante <= 0.0001;

  bool get receitaGerada => idTransacaoReceita != null && idTransacaoReceita!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'data': data.toIso8601String(),
        'nomeCliente': nomeCliente,
        'itens': itens.map((e) => e.toJson()).toList(),
        'valorCobrado': valorCobrado,
        'valorPago': valorPago,
        'observacoes': observacoes,
        'idTransacaoReceita': idTransacaoReceita,
        'idHistorico': idHistorico,
        'nomeItemSalvo': nomeItemSalvo,
        'quantidade': quantidade,
      };

  factory PedidoItem.fromJson(Map<String, dynamic> j) {
    final itensJson = j['itens'] as List<dynamic>?;
    final itens = itensJson != null
        ? itensJson
            .map((e) => PedidoLinhaItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : <PedidoLinhaItem>[];

    if (itens.isEmpty && j['idHistorico'] != null) {
      itens.add(PedidoLinhaItem(
        id: j['idHistorico']?.toString() ?? '',
        idHistorico: j['idHistorico'],
        nomeItemSalvo: j['nomeItemSalvo'] ?? 'Sem item',
        quantidade: ((j['quantidade'] ?? 1) as num).toInt(),
      ));
    }

    return PedidoItem(
      id: j['id'] ?? '',
      data: DateTime.tryParse(j['data'] ?? '') ?? DateTime.now(),
      nomeCliente: j['nomeCliente'] ?? '',
      itens: itens,
      valorCobrado: (j['valorCobrado'] ?? 0.0).toDouble(),
      valorPago: (j['valorPago'] ?? 0.0).toDouble(),
      observacoes: j['observacoes'] ?? '',
      idTransacaoReceita: j['idTransacaoReceita'],
    );
  }
}
